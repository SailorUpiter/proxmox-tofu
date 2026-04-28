# Создание зоны sailor.com
resource "powerdns_zone" "sailor" {
  name        = "sailor.com."
  kind        = "Native"
  nameservers = ["ns1.sailor.com."]
}

# A-записи для OpenSearch нод
resource "powerdns_record" "opensearch" {
  for_each = {
    "opensearch-1" = "192.168.1.121"
    "opensearch-2" = "192.168.1.122"
    "opensearch-3" = "192.168.1.123"
  }

  zone    = powerdns_zone.sailor.name
  name    = "${each.key}.sailor.com."
  type    = "A"
  ttl     = 300
  records = [each.value]
}
