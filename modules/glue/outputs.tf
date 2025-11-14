output "glue_database_name" {
  value = aws_glue_catalog_database.stocks.name
}

output "glue_crawler_name" {
  value = aws_glue_crawler.stock_crawler.name
}
