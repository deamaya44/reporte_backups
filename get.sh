aws backup list-backup-jobs \
  --by-account-id "*" \
  --output json | \
  jq -r '["BackupJobID","Status","AccountID","ResourceName","MessageCategory","ResourceID","ResourceType","CreationTime"], (.BackupJobs[] | [.BackupJobId, .State, .AccountId, .ResourceName // "-", .StatusMessage // "Success", .ResourceArn, .ResourceType, .CreationDate]) | @csv' > cross-account-backup-jobs.csv
