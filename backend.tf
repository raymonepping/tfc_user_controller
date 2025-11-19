terraform {
  cloud {
    organization = "HUGGING_NL"

    workspaces {
      name = "tfc_user_controller"
    }
  }
}
