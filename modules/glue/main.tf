resource "aws_glue_catalog_database" "stocks" {
  name = "stock_db_${var.env}"
}

resource "aws_glue_crawler" "stock_crawler" {
  name          = "stock-crawler-${var.env}"
  database_name = aws_glue_catalog_database.stocks.name
  role          = var.glue_role_arn

  s3_target {
    path = "s3://${var.raw_bucket_name}/"
  }

  schedule = var.crawler_schedule  # fixed line!

  tags = merge(var.tags, {
    Name = "stock-crawler-${var.env}"
  })
}
