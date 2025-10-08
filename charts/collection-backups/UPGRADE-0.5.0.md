# Upgrade Notes: collection-backups 0.5.0

## What's New

Version 0.5.0 adds support for **GKE Workload Identity**, allowing the chart to authenticate to GCS without using JSON key secrets.

## Breaking Changes

None - fully backward compatible with existing deployments.

## New Features

### Workload Identity Support

The chart now supports two authentication methods:

**Option 1: JSON Key Secret (Legacy - Default)**
```yaml
serviceAccount:
  create: false
  name: ""
  useWorkloadIdentity: false

secretCloud: <base64-encoded-json-key>
```

**Option 2: Workload Identity (Recommended)**
```yaml
serviceAccount:
  create: false  # Use existing SA from solr-operator
  name: "solr"   # Name of existing service account
  annotations:
    iam.gke.io/gcp-service-account: my-gcp-sa@project.iam.gserviceaccount.com
  useWorkloadIdentity: true

# No secretCloud needed
```

## Migration Guide

### Prerequisites

1. **GCP Service Account** with GCS permissions
2. **Workload Identity binding** between K8s SA and GCP SA
3. **Updated application image** with Workload Identity support

### Step-by-Step Migration

#### 1. Create GCP Infrastructure (Terraform)

```hcl
# Service Account
resource "google_service_account" "collections_backup" {
  project      = var.project_id
  account_id   = "cluster-backups"
  display_name = "Solr Collection Backups"
}

# GCS Bucket Permissions
resource "google_storage_bucket_iam_member" "collections_backup_admin" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.collections_backup.member
}

# Workload Identity Binding
resource "google_service_account_iam_member" "solr_workload_identity" {
  service_account_id = google_service_account.collections_backup.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/solr]"
}

resource "google_service_account_iam_member" "backup_cronjob_workload_identity" {
  service_account_id = google_service_account.collections_backup.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/collection-backups]"
}
```

#### 2. Ensure Solr ServiceAccount has Workload Identity Annotation

The Solr operator should automatically add this annotation to the `solr` service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: solr
  annotations:
    iam.gke.io/gcp-service-account: cluster-backups@project.iam.gserviceaccount.com
```

Verify:
```bash
kubectl get sa solr -n <namespace> -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'
```

#### 3. Update Helm Values

```yaml
# values.yaml
collection-backups:
  image:
    tag: test-srch-412  # Use image with Workload Identity support

  bucketName: my-cluster-solr-backups
  maxBackupPoints: 400

  serviceAccount:
    create: false
    name: solr  # Use existing SA from solr-operator
    useWorkloadIdentity: true

  # Remove these (no longer needed):
  # secretCloud: ...
  # secretName: ...
```

#### 4. Deploy Updated Chart

```bash
helm upgrade collection-backups ./collection-backups \
  -n <namespace> \
  -f values.yaml
```

#### 5. Verify

**Check Pod Status:**
```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=collection-backups
```

**Check Logs for Workload Identity:**
```bash
kubectl logs -n <namespace> deployment/collection-backups

# Expected output:
# INFO: Authenticating with GCS using Application Default Credentials (Workload Identity)
# INFO: Successfully connected to GCS bucket: my-cluster-solr-backups
```

**Trigger Manual Backup:**
```bash
kubectl create job --from=cronjob/collection-backups manual-test -n <namespace>
kubectl logs -f job/manual-test -n <namespace>
```

#### 6. Cleanup Old Secrets (After Validation)

```bash
# Remove old JSON key secret
kubectl delete secret collection-backup-sa -n <namespace>
```

## Configuration Reference

### serviceAccount

| Parameter | Description | Default |
|-----------|-------------|---------|
| `create` | Create a new service account | `false` |
| `name` | Name of service account to use | `""` (uses default) |
| `annotations` | Annotations for Workload Identity | `{}` |
| `useWorkloadIdentity` | Enable Workload Identity mode | `false` |

### Example Configurations

**Minimal (Using existing SA)**:
```yaml
serviceAccount:
  name: solr
  useWorkloadIdentity: true
```

**Create New SA with Workload Identity**:
```yaml
serviceAccount:
  create: true
  name: collection-backups
  annotations:
    iam.gke.io/gcp-service-account: backups@project.iam.gserviceaccount.com
  useWorkloadIdentity: true
```

**Legacy (JSON Key)**:
```yaml
serviceAccount:
  useWorkloadIdentity: false

secretCloud: <base64-json-key>
```

## Troubleshooting

### Error: "Unable to authenticate with GCS"

**Check Workload Identity binding:**
```bash
gcloud iam service-accounts get-iam-policy backups@project.iam.gserviceaccount.com
```

Should show:
```yaml
bindings:
- members:
  - serviceAccount:project.svc.id.goog[namespace/solr]
  role: roles/iam.workloadIdentityUser
```

### Error: "Permission denied" on GCS

**Check GCS IAM permissions:**
```bash
gcloud storage buckets get-iam-policy gs://bucket-name
```

Service account should have `roles/storage.objectAdmin`.

### Backup still using JSON key

**Check environment variable:**
```bash
kubectl exec -n <namespace> deployment/collection-backups -- env | grep BACKUP_GCS_CREDENTIALS_PATH
```

Should be empty when using Workload Identity:
```
BACKUP_GCS_CREDENTIALS_PATH=
```

## Benefits of Workload Identity

✅ **Security**: No JSON keys stored in cluster
✅ **Automatic Rotation**: GCP manages credentials
✅ **Fine-grained Access**: Per-namespace IAM bindings
✅ **Audit Trail**: Better GCP audit logs
✅ **Simpler Operations**: No secret management

## Rollback

To rollback to JSON key authentication:

```yaml
serviceAccount:
  useWorkloadIdentity: false

secretCloud: <base64-json-key>
```

Then upgrade/rollback the chart.
