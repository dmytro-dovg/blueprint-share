local Config = {
  -- 65535 - 20 (IPv4 header) - 8 (UDP header).
  max_udp_packet_size = 65507,
  inbox_size = 5,
}

return Config
