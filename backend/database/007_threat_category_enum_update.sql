-- Reconcile Threat Category enum list to support canonical categories
USE url_defender;

ALTER TABLE community_reports 
  MODIFY COLUMN threat_category ENUM(
    'phishing', 
    'malware', 
    'scam', 
    'fake_login', 
    'crypto_scam', 
    'spam', 
    'unsafe_download', 
    'fake_banking', 
    'investment_scam', 
    'fake_shopping', 
    'identity_theft', 
    'other'
  ) NOT NULL;

ALTER TABLE verified_community_intelligence 
  MODIFY COLUMN threat_category ENUM(
    'phishing', 
    'malware', 
    'scam', 
    'fake_login', 
    'crypto_scam', 
    'spam', 
    'unsafe_download', 
    'fake_banking', 
    'investment_scam', 
    'fake_shopping', 
    'identity_theft', 
    'other'
  ) NOT NULL;
