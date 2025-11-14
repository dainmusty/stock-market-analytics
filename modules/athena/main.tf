resource "aws_athena_database" "stock_db" {
  name   = var.glue_database_name
  bucket = var.athena_results_bucket_name
}

resource "aws_athena_named_query" "recent" {
  name        = "recent-stock-records"
  database    = aws_athena_database.stock_db.name
  query       = "SELECT * FROM stocks_table LIMIT 10;"
  description = "Fetch recent stock records"
}
