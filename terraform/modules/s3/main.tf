resource "aws_s3_bucket" "main" {
  bucket_prefix = "${var.project_name}-${var.environment}-data-"
  force_destroy = true # For easier cleanup in this demo project

  tags = {
    Name = "${var.project_name}-${var.environment}-data-bucket"
  }
}

# Create folders (prefixes)
resource "aws_s3_object" "bronze" {
  bucket = aws_s3_bucket.main.id
  key    = "bronze/"
}

resource "aws_s3_object" "silver" {
  bucket = aws_s3_bucket.main.id
  key    = "silver/"
}

resource "aws_s3_object" "scripts" {
  bucket = aws_s3_bucket.main.id
  key    = "scripts/"
}
