# ============================================================
# IAM ACCESS ANALYZER
# ============================================================
# Continuously analyzes resource policies to find any that grant
# access to external principals — catches overly broad permissions.

resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "cloud-resume-analyzer"
  type          = "ACCOUNT"
}

# ============================================================
# DATA SOURCES
# ============================================================

data "aws_caller_identity" "current" {}
