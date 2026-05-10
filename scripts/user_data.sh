#!/bin/bash
set -euo pipefail

# Update system
dnf update -y

# Install Nginx and utilities
dnf install -y nginx curl jq

# Get instance metadata (IMDSv2 — more secure than v1)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4 || echo "N/A")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)
INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-type)
BOOT_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')

# Configure Nginx — serve static files directly
cat > /etc/nginx/conf.d/myapp.conf << 'NGINXCONF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/myapp;
    index index.html;

    # Health check endpoint for ALB
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINXCONF

# Remove default nginx config to avoid conflicts
rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

# Create the web application
# NOTE: This is a standalone reference copy of the user_data.
# The actual template with Terraform variables is in modules/compute/main.tf
# Replace PROJECT_NAME and ENVIRONMENT with your values if running standalone.
mkdir -p /var/www/myapp
cat > /var/www/myapp/index.html << HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MyApp Dashboard</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root{--bg:#0a0a1a;--card:rgba(255,255,255,0.04);--border:rgba(255,255,255,0.08);--accent:#6366f1;--text:#f1f5f9;--muted:#94a3b8;--green:#22c55e}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh;background-image:radial-gradient(ellipse at 20% 50%,rgba(99,102,241,0.08) 0%,transparent 50%),radial-gradient(ellipse at 80% 20%,rgba(168,85,247,0.06) 0%,transparent 50%)}
    .wrap{max-width:880px;margin:0 auto;padding:2.5rem 1.5rem}
    .hdr{text-align:center;margin-bottom:2.5rem}
    .badge{display:inline-flex;align-items:center;gap:6px;padding:4px 14px;border-radius:999px;background:rgba(34,197,94,0.1);border:1px solid rgba(34,197,94,0.2);color:var(--green);font-size:.7rem;font-weight:500;text-transform:uppercase;letter-spacing:.05em;margin-bottom:1rem}
    .dot{width:6px;height:6px;border-radius:50%;background:var(--green);animation:pulse 2s infinite}
    @keyframes pulse{0%,100%{opacity:1}50%{opacity:.3}}
    h1{font-size:2rem;font-weight:700;margin-bottom:.4rem;background:linear-gradient(135deg,#f1f5f9,#6366f1);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
    .sub{color:var(--muted);font-size:.85rem}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:1rem;margin-bottom:1.25rem}
    .card{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:1.25rem;backdrop-filter:blur(10px);transition:border-color .3s,transform .2s}
    .card:hover{border-color:rgba(99,102,241,.3);transform:translateY(-2px)}
    .lbl{font-size:.65rem;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin-bottom:.35rem}
    .val{font-size:1rem;font-weight:600;font-family:'Courier New',monospace;word-break:break-all}
    .card-wide{grid-column:1/-1}
    .clock{font-size:2.2rem;font-weight:300;text-align:center;font-family:'Courier New',monospace;color:var(--accent);letter-spacing:.04em}
    .ft{text-align:center;padding:2rem;color:var(--muted);font-size:.7rem}
    .tag{display:inline-block;padding:2px 8px;border-radius:6px;font-size:.7rem;font-weight:500;margin-right:4px}
    .tag-blue{background:rgba(99,102,241,.15);color:#818cf8}
    .tag-green{background:rgba(34,197,94,.15);color:#4ade80}
    .tag-purple{background:rgba(168,85,247,.15);color:#c084fc}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hdr">
      <div class="badge"><span class="dot"></span> Online</div>
      <h1>myapp</h1>
      <p class="sub">
        <span class="tag tag-blue">production</span>
        <span class="tag tag-green">Terraform</span>
        <span class="tag tag-purple">AWS</span>
      </p>
    </div>
    <div class="grid">
      <div class="card"><div class="lbl">Instance ID</div><div class="val">$INSTANCE_ID</div></div>
      <div class="card"><div class="lbl">Instance Type</div><div class="val">$INSTANCE_TYPE</div></div>
      <div class="card"><div class="lbl">Availability Zone</div><div class="val">$AZ</div></div>
      <div class="card"><div class="lbl">Private IP</div><div class="val">$PRIVATE_IP</div></div>
      <div class="card"><div class="lbl">Public IP</div><div class="val">$PUBLIC_IP</div></div>
      <div class="card"><div class="lbl">Boot Time</div><div class="val">$BOOT_TIME</div></div>
      <div class="card card-wide">
        <div class="lbl">Live Clock (UTC)</div>
        <div class="clock" id="clock">--:--:--</div>
      </div>
    </div>
    <div class="ft">Managed by Terraform &bull; myapp &bull; production</div>
  </div>
  <script>
    function tick(){var d=new Date();var h=String(d.getUTCHours()).padStart(2,'0');var m=String(d.getUTCMinutes()).padStart(2,'0');var s=String(d.getUTCSeconds()).padStart(2,'0');document.getElementById('clock').textContent=h+':'+m+':'+s}
    setInterval(tick,1000);tick();
  </script>
</body>
</html>
HTML

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

echo "Bootstrap complete: $(date)" >> /var/log/user-data.log
