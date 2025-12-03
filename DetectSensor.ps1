if (-not (Get-Service -Name CloudEndpointService -ErrorAction SilentlyContinue)) { exit 0 } else { exit 1 }
