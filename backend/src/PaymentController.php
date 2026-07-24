<?php
declare(strict_types=1);

final class PaymentController
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function plans(): array
    {
        return ['items' => [
            ['id' => 'team', 'amount_paise' => (int) env('TEAM_PRICE_PAISE', '9900'), 'currency' => 'INR'],
            ['id' => 'enterprise', 'amount_paise' => (int) env('ENTERPRISE_PRICE_PAISE', '49900'), 'currency' => 'INR'],
        ]];
    }

    public function createOrder(array $user, array $input): array
    {
        $plan = (string) ($input['plan'] ?? '');
        if (!in_array($plan, ['team', 'enterprise'], true)) {
            throw new HttpException(422, 'Select the team or enterprise plan.');
        }
        $amount = $plan === 'team' ? (int) env('TEAM_PRICE_PAISE', '9900') : (int) env('ENTERPRISE_PRICE_PAISE', '49900');

        // Apply coupon code if provided
        $coupon = strtoupper(trim((string) ($input['coupon'] ?? '')));
        if ($coupon !== '') {
            if ($coupon === 'SECURE50') {
                $amount = (int) ($amount * 0.5);
            } else if ($coupon === 'DEFENDER10') {
                $amount = (int) ($amount * 0.9);
            } else {
                throw new HttpException(400, 'Invalid coupon code.');
            }
        }

        if ($amount < 100) {
            throw new RuntimeException('Configured plan price is invalid.');
        }

        $keyId = env('RAZORPAY_KEY_ID');
        $keySecret = env('RAZORPAY_KEY_SECRET');
        $isMock = ($keyId === null || $keyId === '' || $keySecret === null || $keySecret === '') && env('APP_ENV') === 'development';

        $receipt = 'rcpt_' . bin2hex(random_bytes(20));

        if ($isMock) {
            $orderId = 'order_mock_' . bin2hex(random_bytes(10));
        } else {
            $order = $this->razorpay('POST', '/orders', [
                'amount' => $amount,
                'currency' => 'INR',
                'receipt' => $receipt,
                'notes' => ['user_id' => $user['id'], 'plan' => $plan],
            ]);
            $orderId = (string) ($order['id'] ?? '');
            if ($orderId === '') {
                throw new RuntimeException('Payment provider did not return an order identifier.');
            }
        }

        $subscriptionId = uuid();
        $paymentId = uuid();
        $this->db->beginTransaction();
        try {
            $this->db->prepare("INSERT INTO subscriptions (id, user_id, plan, status, current_period_start, current_period_end) VALUES (?, ?, ?, 'trialing', UTC_TIMESTAMP(), DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))")
                ->execute([$subscriptionId, $user['id'], $plan]);
            $this->db->prepare('INSERT INTO payments (id, user_id, subscription_id, razorpay_order_id, receipt, amount_paise, currency, status) VALUES (?, ?, ?, ?, ?, ?, ?, ? )')
                ->execute([$paymentId, $user['id'], $subscriptionId, $orderId, $receipt, $amount, 'INR', 'created']);
            $this->audit($user['id'], 'billing.order_created', ['payment_id' => $paymentId, 'plan' => $plan]);
            $this->db->commit();
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
        return ['key_id' => $isMock ? 'rzp_test_mock' : $keyId, 'order_id' => $orderId, 'amount_paise' => $amount, 'currency' => 'INR', 'plan' => $plan];
    }

    public function verifyOrder(array $user, array $input): array
    {
        $orderId = trim((string) ($input['razorpay_order_id'] ?? ''));
        $providerPaymentId = trim((string) ($input['razorpay_payment_id'] ?? ''));
        $signature = trim((string) ($input['razorpay_signature'] ?? ''));
        if ($orderId === '' || $providerPaymentId === '' || $signature === '') {
            throw new HttpException(422, 'Payment order, payment ID, and signature are required.');
        }

        // Handle mock verification bypass — ONLY in development mode.
        if (str_starts_with($orderId, 'order_mock_')) {
            if (env('APP_ENV') !== 'development') {
                throw new HttpException(400, 'Invalid payment order.');
            }
            $payment = $this->paymentForOrder($orderId, $user['id']);
            $this->applyPayment($payment, 'captured', $providerPaymentId, $signature, 'mock_method', null);
            return ['status' => 'captured', 'message' => 'Payment confirmed.'];
        }

        $expected = hash_hmac('sha256', $orderId . '|' . $providerPaymentId, $this->razorpaySecret());
        if (!hash_equals($expected, $signature)) {
            throw new HttpException(400, 'Invalid payment signature.');
        }
        $payment = $this->paymentForOrder($orderId, $user['id']);
        $provider = $this->razorpay('GET', '/payments/' . rawurlencode($providerPaymentId));
        if (($provider['order_id'] ?? null) !== $orderId || (int) ($provider['amount'] ?? 0) !== (int) $payment['amount_paise'] || ($provider['currency'] ?? null) !== $payment['currency']) {
            throw new HttpException(400, 'Payment details do not match this order.');
        }
        $status = (string) ($provider['status'] ?? 'created');
        if (!in_array($status, ['authorized', 'captured', 'failed'], true)) {
            throw new HttpException(409, 'Payment is still being processed.');
        }
        $this->applyPayment($payment, $status, $providerPaymentId, $signature, $provider['method'] ?? null, $provider['error_description'] ?? null);
        return ['status' => $status, 'message' => $status === 'captured' ? 'Payment confirmed.' : 'Payment is awaiting capture.'];
    }

    public function webhook(string $rawPayload, string $signature): array
    {
        $secret = env('RAZORPAY_WEBHOOK_SECRET');
        if ($secret === null || $secret === '' || !hash_equals(hash_hmac('sha256', $rawPayload, $secret), $signature)) {
            throw new HttpException(400, 'Invalid webhook signature.');
        }
        $event = json_decode($rawPayload, true);
        if (!is_array($event)) {
            throw new HttpException(400, 'Webhook body must be valid JSON.');
        }
        $hash = hash('sha256', $rawPayload);
        $eventType = substr((string) ($event['event'] ?? 'unknown'), 0, 120);
        try {
            $this->db->prepare('INSERT INTO webhook_events (id, provider, event_hash, event_type, payload) VALUES (?, ?, ?, ?, ?)')
                ->execute([uuid(), 'razorpay', $hash, $eventType, $rawPayload]);
        } catch (PDOException $error) {
            if ($error->getCode() === '23000') {
                $existing = $this->db->prepare('SELECT processed_at FROM webhook_events WHERE provider = ? AND event_hash = ? LIMIT 1');
                $existing->execute(['razorpay', $hash]);
                $existingEvent = $existing->fetch();
                if (!$existingEvent || $existingEvent['processed_at'] !== null) {
                    return ['message' => 'Webhook already processed.'];
                }
            } else {
                throw $error;
            }
        }
        $entity = $event['payload']['payment']['entity'] ?? [];
        $orderId = is_array($entity) ? (string) ($entity['order_id'] ?? '') : '';
        if ($orderId !== '') {
            $payment = $this->paymentForOrder($orderId);
            if ($payment) {
                $status = match ($eventType) {
                    'payment.captured' => 'captured',
                    'payment.authorized' => 'authorized',
                    'payment.failed' => 'failed',
                    'refund.created', 'refund.processed' => 'refunded',
                    default => null,
                };
                if ($status !== null) {
                    $this->applyPayment($payment, $status, (string) ($entity['id'] ?? ''), null, $entity['method'] ?? null, $entity['error_description'] ?? null);
                }
            }
        }
        $this->db->prepare('UPDATE webhook_events SET processed_at = UTC_TIMESTAMP() WHERE provider = ? AND event_hash = ?')->execute(['razorpay', $hash]);
        return ['message' => 'Webhook processed.'];
    }

    public function listPayments(array $user): array
    {
        $stmt = $this->db->prepare('SELECT id, subscription_id, amount_paise, currency, method, status, failure_reason, created_at, updated_at FROM payments WHERE user_id = ? ORDER BY created_at DESC LIMIT 100');
        $stmt->execute([$user['id']]);
        return ['items' => $stmt->fetchAll()];
    }

    private function paymentForOrder(string $orderId, ?string $userId = null): array|false
    {
        $sql = 'SELECT p.*, s.plan FROM payments p LEFT JOIN subscriptions s ON s.id = p.subscription_id WHERE p.razorpay_order_id = ?';
        $args = [$orderId];
        if ($userId !== null) {
            $sql .= ' AND p.user_id = ?';
            $args[] = $userId;
        }
        $stmt = $this->db->prepare($sql . ' LIMIT 1');
        $stmt->execute($args);
        $payment = $stmt->fetch();
        if (!$payment && $userId !== null) {
            throw new HttpException(404, 'Payment order not found.');
        }
        return $payment;
    }

    private function applyPayment(array $payment, string $status, string $providerPaymentId = '', ?string $signature = null, ?string $method = null, ?string $failure = null): void
    {
        $allowedMethod = in_array($method, ['upi', 'card', 'netbanking', 'wallet', 'emi'], true) ? $method : null;
        $this->db->beginTransaction();
        try {
            $current = $this->db->prepare('SELECT status FROM payments WHERE id = ? FOR UPDATE');
            $current->execute([$payment['id']]);
            $currentStatus = $current->fetchColumn();
            if ($currentStatus === $status || ($currentStatus === 'captured' && $status !== 'refunded')) {
                $this->db->commit();
                return;
            }
            $this->db->prepare('UPDATE payments SET status = ?, razorpay_payment_id = COALESCE(NULLIF(?, \'\'), razorpay_payment_id), razorpay_signature = COALESCE(?, razorpay_signature), method = COALESCE(?, method), failure_reason = ? WHERE id = ?')
                ->execute([$status, $providerPaymentId, $signature, $allowedMethod, $failure ? substr((string) $failure, 0, 255) : null, $payment['id']]);
            if ($payment['subscription_id']) {
                if ($status === 'captured') {
                    $this->db->prepare("UPDATE subscriptions SET status = 'active' WHERE id = ?")->execute([$payment['subscription_id']]);
                    $this->db->prepare('UPDATE users SET plan = ? WHERE id = ?')->execute([$payment['plan'], $payment['user_id']]);
                    $this->notification($payment['user_id'], 'billing', 'Plan activated', 'Your ' . $payment['plan'] . ' plan is active.', 'info');
                } elseif (in_array($status, ['failed', 'refunded'], true)) {
                    $this->db->prepare("UPDATE subscriptions SET status = 'past_due' WHERE id = ?")->execute([$payment['subscription_id']]);
                }
            }
            $this->audit($payment['user_id'], 'billing.payment_' . $status, ['payment_id' => $payment['id']]);
            $this->db->commit();
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    private function razorpay(string $method, string $path, ?array $body = null): array
    {
        $keyId = env('RAZORPAY_KEY_ID');
        if ($keyId === null || $keyId === '') {
            throw new RuntimeException('RAZORPAY_KEY_ID is not configured.');
        }
        $response = HttpClient::request($method, 'https://api.razorpay.com/v1' . $path, [], $body, $keyId, $this->razorpaySecret());
        if ($response['status'] < 200 || $response['status'] >= 300) {
            throw new RuntimeException('Razorpay request failed with HTTP ' . $response['status'] . '.');
        }
        return $response['body'];
    }

    private function razorpaySecret(): string
    {
        $secret = env('RAZORPAY_KEY_SECRET');
        if ($secret === null || $secret === '') {
            throw new RuntimeException('RAZORPAY_KEY_SECRET is not configured.');
        }
        return $secret;
    }

    private function notification(string $userId, string $type, string $title, string $message, string $severity): void
    {
        $this->db->prepare('INSERT INTO notifications (id, user_id, type, title, message, severity) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([uuid(), $userId, $type, $title, $message, $severity]);
    }

    private function audit(string $userId, string $action, array $metadata): void
    {
        $this->db->prepare('INSERT INTO audit_log (user_id, action, ip_address, user_agent, metadata) VALUES (?, ?, ?, ?, ?)')
            ->execute([$userId, $action, clientIp(), userAgent(), json_encode($metadata)]);
    }

    public function validateCoupon(array $user, array $input): array
    {
        $code = strtoupper(trim((string) ($input['code'] ?? '')));
        if ($code === '') {
            throw new HttpException(400, 'Coupon code is required.');
        }

        if ($code === 'SECURE50') {
            return [
                'valid' => true,
                'code' => 'SECURE50',
                'discount_percent' => 50,
                'message' => '50% discount applied successfully.'
            ];
        }

        if ($code === 'DEFENDER10') {
            return [
                'valid' => true,
                'code' => 'DEFENDER10',
                'discount_percent' => 10,
                'message' => '10% discount applied successfully.'
            ];
        }

        throw new HttpException(400, 'Invalid or expired coupon code.');
    }

    public function cancelSubscription(array $user): array
    {
        // Update subscription status to cancelled
        $stmt = $this->db->prepare("UPDATE subscriptions SET status = 'cancelled' WHERE user_id = ? AND status = 'active'");
        $stmt->execute([$user['id']]);
        
        // Update user plan to free
        $stmtUser = $this->db->prepare("UPDATE users SET plan = 'free' WHERE id = ?");
        $stmtUser->execute([$user['id']]);
        
        $this->audit($user['id'], 'billing.subscription_cancelled', []);
        return ['message' => 'Subscription cancelled successfully.'];
    }
}
