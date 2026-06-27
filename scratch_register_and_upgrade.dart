// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://twqjejtpqybegyidwwaz.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3cWplanRwcXliZWd5aWR3d2F6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODI3MjUsImV4cCI6MjA5NjU1ODcyNX0.laDaP72O65aQagyxafgn1KDAL1cZaGsbbc5Cl1ZNi3s';
  final email = 'testdb_user@gmail.com';
  final password = 'Password123';

  final client = HttpClient();

  print('1. Attempting to sign up user $email...');
  String? accessToken;
  String? userId;

  final signupUri = Uri.parse('$supabaseUrl/auth/v1/signup');
  final signupRequest = await client.postUrl(signupUri);
  signupRequest.headers.add('apikey', anonKey);
  signupRequest.headers.add('Content-Type', 'application/json');
  signupRequest.add(utf8.encode(jsonEncode({
    'email': email,
    'password': password,
  })));
  
  final signupResponse = await signupRequest.close();
  final signupBody = await signupResponse.transform(utf8.decoder).join();
  print('Signup status: ${signupResponse.statusCode}');
  
  if (signupResponse.statusCode == 200 || signupResponse.statusCode == 201) {
    final data = jsonDecode(signupBody);
    accessToken = data['access_token'];
    userId = data['user']['id'];
    print('Signup successful! User ID: $userId');
  } else {
    print('Signup failed (status ${signupResponse.statusCode}): $signupBody. Attempting sign in...');
    final signinUri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
    final signinRequest = await client.postUrl(signinUri);
    signinRequest.headers.add('apikey', anonKey);
    signinRequest.headers.add('Content-Type', 'application/json');
    signinRequest.add(utf8.encode(jsonEncode({
      'email': email,
      'password': password,
    })));
    
    final signinResponse = await signinRequest.close();
    final signinBody = await signinResponse.transform(utf8.decoder).join();
    print('Signin status: ${signinResponse.statusCode}');
    if (signinResponse.statusCode == 200) {
      final data = jsonDecode(signinBody);
      accessToken = data['access_token'];
      userId = data['user']['id'];
      print('Signin successful! User ID: $userId');
    } else {
      print('Signin failed! Response: $signinBody');
      client.close();
      return;
    }
  }

  if (accessToken == null || userId == null) {
    print('Error: Auth tokens not retrieved.');
    client.close();
    return;
  }

  print('2. Fetching active pricing plans...');
  final planUri = Uri.parse('$supabaseUrl/rest/v1/plans?is_active=eq.true');
  final planRequest = await client.getUrl(planUri);
  planRequest.headers.add('apikey', anonKey);
  planRequest.headers.add('Authorization', 'Bearer $anonKey');
  final planResponse = await planRequest.close();
  final planBody = await planResponse.transform(utf8.decoder).join();
  final List plans = jsonDecode(planBody);
  if (plans.isEmpty) {
    print('No active plans found!');
    client.close();
    return;
  }
  
  final plan = plans.first;
  final planId = plan['plan_id'];
  final price = plan['price'];
  print('Using planId: $planId (price: $price)');

  print('3. Checking if user profile exists in users table...');
  final userSearchUri = Uri.parse('$supabaseUrl/rest/v1/users?user_id=eq.$userId');
  final userSearchRequest = await client.getUrl(userSearchUri);
  userSearchRequest.headers.add('apikey', anonKey);
  userSearchRequest.headers.add('Authorization', 'Bearer $accessToken');
  final userSearchResponse = await userSearchRequest.close();
  final userSearchBody = await userSearchResponse.transform(utf8.decoder).join();
  final List userProfiles = jsonDecode(userSearchBody);

  if (userProfiles.isEmpty) {
    print('Creating a new user profile with is_premium = true...');
    final insertUri = Uri.parse('$supabaseUrl/rest/v1/users');
    final insertRequest = await client.postUrl(insertUri);
    insertRequest.headers.add('apikey', anonKey);
    insertRequest.headers.add('Authorization', 'Bearer $accessToken');
    insertRequest.headers.add('Content-Type', 'application/json');
    insertRequest.add(utf8.encode(jsonEncode({
      'user_id': userId,
      'username': 'nexabot4',
      'email': email,
      'role': 'user',
      'is_premium': true,
    })));
    final insertResponse = await insertRequest.close();
    final insertResBody = await insertResponse.transform(utf8.decoder).join();
    print('Profile insert status: ${insertResponse.statusCode}, body: $insertResBody');
  } else {
    print('User profile already exists. Updating is_premium = true...');
    final updateUri = Uri.parse('$supabaseUrl/rest/v1/users?user_id=eq.$userId');
    final updateRequest = await client.patchUrl(updateUri);
    updateRequest.headers.add('apikey', anonKey);
    updateRequest.headers.add('Authorization', 'Bearer $accessToken');
    updateRequest.headers.add('Content-Type', 'application/json');
    updateRequest.add(utf8.encode(jsonEncode({'is_premium': true})));
    final updateResponse = await updateRequest.close();
    print('Profile update status: ${updateResponse.statusCode}');
  }

  print('4. Inserting dummy scans (safe and dangerous) into url_scans table...');
  
  // Safe scan
  final scanInsertRequest1 = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/url_scans'));
  scanInsertRequest1.headers.add('apikey', anonKey);
  scanInsertRequest1.headers.add('Authorization', 'Bearer $accessToken');
  scanInsertRequest1.headers.add('Content-Type', 'application/json');
  scanInsertRequest1.add(utf8.encode(jsonEncode({
    'user_id': userId,
    'scanned_url': 'https://google.com',
    'scan_result': 'safe',
    'threat_type': null,
    'risk_score': 0,
    'virus_total_flags': 0,
    'heuristic_hits': 0,
    'community_reports': 100,
  })));
  final scanInsertResponse1 = await scanInsertRequest1.close();
  await scanInsertResponse1.drain();
  print('Safe Scan insert status: ${scanInsertResponse1.statusCode}');

  // Dangerous scan
  final scanInsertRequest2 = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/url_scans'));
  scanInsertRequest2.headers.add('apikey', anonKey);
  scanInsertRequest2.headers.add('Authorization', 'Bearer $accessToken');
  scanInsertRequest2.headers.add('Content-Type', 'application/json');
  scanInsertRequest2.add(utf8.encode(jsonEncode({
    'user_id': userId,
    'scanned_url': 'https://malicious-phishing-site.com',
    'scan_result': 'dangerous',
    'threat_type': 'phishing',
    'risk_score': 85,
    'virus_total_flags': 12,
    'heuristic_hits': 4,
    'community_reports': 25,
  })));
  final scanInsertResponse2 = await scanInsertRequest2.close();
  await scanInsertResponse2.drain();
  print('Dangerous Scan insert status: ${scanInsertResponse2.statusCode}');

  print('5. Inserting dummy blocked URL in blocked_urls table...');
  final blockInsertRequest = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/blocked_urls'));
  blockInsertRequest.headers.add('apikey', anonKey);
  blockInsertRequest.headers.add('Authorization', 'Bearer $accessToken');
  blockInsertRequest.headers.add('Content-Type', 'application/json');
  blockInsertRequest.add(utf8.encode(jsonEncode({
    'user_id': userId,
    'url': 'https://blocked-malware-test.com',
    'reason': 'malware',
  })));
  final blockInsertResponse = await blockInsertRequest.close();
  final blockInsertBody = await blockInsertResponse.transform(utf8.decoder).join();
  print('Blocked URL insert status: ${blockInsertResponse.statusCode}, body: $blockInsertBody');

  print('Done testing and setting up user $email!');
  client.close();
}
