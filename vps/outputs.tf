output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "initial_password" {
  value = "${file("${local.workdir}/output/initialpwd")}"
}
