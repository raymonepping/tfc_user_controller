########################################
# Load bootstrap emails (if file exists)
########################################

locals {
  bootstrap_obj    = try(jsondecode(file(var.bootstrap_file)), { emails = [] })
  bootstrap_emails = toset([for e in local.bootstrap_obj.emails : lower(e)])
}

########################################
# Effective emails and usernames
########################################

locals {
  effective_using_locked = var.email_source == "locked" ? true : var.using_locked

  effective_emails = (
    var.email_source == "locked"    ? toset(keys(var.users)) :
    var.email_source == "variable"  ? toset([for e in var.emails : lower(e)]) :
    /* bootstrap */                   local.bootstrap_emails
  )

  usernames = (
    local.effective_using_locked
    ? { for e, u in var.users : e => u.username }
    : { for e in local.effective_emails :
        e => replace(
          replace(
            replace(lower(element(split("@", e), 0)), ".", "_"),
            "+", "_"
          ),
          "-", "_"
        )
      }
  )
}

########################################
# Organization memberships
########################################

locals {
  org_membership_map = {
    for email in local.effective_emails : email => email
  }
}

resource "tfe_organization_membership" "org_membership" {
  # Always keep memberships declared. Locked mode is handled
  # by where we read IDs from, not by removing the resource.
  for_each     = local.org_membership_map
  organization = var.tfe_organization
  email        = each.key

  lifecycle {
    ignore_changes  = [email]
    prevent_destroy = true
  }
}

#############################################
# Resolved IDs for locked and bootstrap modes
#############################################

locals {
  membership_ids = (
    local.effective_using_locked
    ? { for e, u in var.users : e => u.membership_id }
    : { for e, m in tfe_organization_membership.org_membership : e => m.id }
  )

  user_ids = (
    local.effective_using_locked
    ? { for e, u in var.users : e => try(u.user_id, "") }
    : { for e in local.effective_emails : e => "" }
  )
}

########################################
# Persist credentials for steady state
########################################

locals {
  users_to_persist = local.effective_using_locked ? var.users : {
    for e in local.effective_emails : e => {
      username      = local.usernames[e]
      membership_id = local.membership_ids[e]
      user_id       = local.user_ids[e]
    }
  }
}

resource "local_file" "persist_credentials" {
  count    = var.using_locked || !var.write_credentials_file ? 0 : 1
  filename = "${path.cwd}/credentials.auto.tfvars.json"
  content = jsonencode({
    users = local.users_to_persist
  })
}
