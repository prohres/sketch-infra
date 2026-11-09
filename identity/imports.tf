# One-off imports of the AdministratorAccess permission set created manually on 2026-11-07. Remove after apply.
import {
  to = aws_ssoadmin_permission_set.this["AdministratorAccess"]
  id = "arn:aws:sso:::permissionSet/ssoins-698780933877f42c/ps-6987d24e016e74a6,arn:aws:sso:::instance/ssoins-698780933877f42c"
}

import {
  to = aws_ssoadmin_managed_policy_attachment.this["AdministratorAccess"]
  id = "arn:aws:iam::aws:policy/AdministratorAccess,arn:aws:sso:::permissionSet/ssoins-698780933877f42c/ps-6987d24e016e74a6,arn:aws:sso:::instance/ssoins-698780933877f42c"
}
