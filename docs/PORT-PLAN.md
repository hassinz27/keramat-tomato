# Port compatibility plan

Target compatibility, not a claim that every port is active:

- SSH: 22
- WS non-TLS: 80
- TLS primary: 443
- Alternate HTTP/WS: 8080, 8880, 2082, 2095
- Alternate TLS: 8443
- OpenVPN: 1194

Moving VLESS TLS to public port 443 requires a separate tested migration and rollback plan. Do not replace live listeners without testing.
