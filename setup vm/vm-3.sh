#!/bin/bash

# Add user local bin to PATH for websockify
export PATH="$HOME/.local/bin:$PATH"

# Disable exit on error for better control
set -uo pipefail

# Handle interrupt signals (Ctrl+C) - VMs keep running
handle_interrupt() {
    echo
    echo
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║          Script Closed - Everything Keeps Running!        ║${RESET}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${GREEN}${BOLD}[✓]${RESET} ${GREEN}All VMs running in background${RESET}"
    echo -e "${GREEN}${BOLD}[✓]${RESET} ${GREEN}All noVNC web consoles running${RESET}"
    echo -e "${BLUE}${BOLD}[ℹ]${RESET} ${BLUE}Control: sudo systemctl start/stop vm-NAME${RESET}"
    echo
    
    exit 0
}

# Function to stop all manually started noVNC processes
stop_all_manual_novnc() {
    local stopped=0
    
    # Find all noVNC PID files
    if [ -d "$VM_DIR/pids" ]; then
        for pid_file in "$VM_DIR/pids"/*-novnc.pid; do
            [ -f "$pid_file" ] || continue
            
            local vm_name=$(basename "$pid_file" | sed 's/-novnc\.pid$//')
            local pid=$(cat "$pid_file" 2>/dev/null)
            
            # Check if this noVNC is managed by systemd
            if sudo systemctl is-active "vm-${vm_name}-novnc.service" &>/dev/null 2>&1; then
                # Systemd managed - leave it running
                continue
            fi
            
            # Manual process - stop it
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                rm -f "$pid_file"
                ((stopped++))
            else
                # Stale PID file
                rm -f "$pid_file"
            fi
        done
    fi
    
    if [ $stopped -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}[!]${RESET} ${YELLOW}Stopped $stopped manual noVNC process(es)${RESET}"
        echo -e "${BLUE}${BOLD}[ℹ]${RESET} ${BLUE}Systemd-managed noVNC services continue running${RESET}"
    fi
}

# Function to create VNC control panel
create_vnc_control_panel() {
    local vm_name=$1
    local novnc_port=$2
    
    # Create web directory for this VM
    local web_dir="$VM_DIR/web/$vm_name"
    mkdir -p "$web_dir"
    
    # Copy noVNC files if they exist
    local novnc_source=""
    for dir in "$VM_DIR/novnc" "$HOME/.novnc" "/usr/share/novnc"; do
        if [ -d "$dir" ] && [ -f "$dir/vnc.html" ]; then
            novnc_source="$dir"
            break
        fi
    done
    
    if [ -n "$novnc_source" ]; then
        # Create symlinks to noVNC files, but DON'T expose vnc.html directly
        for item in "$novnc_source"/*; do
            local basename=$(basename "$item")
            if [ "$basename" = "vnc.html" ]; then
                # Copy original vnc.html content to vnc_real.html (hidden)
                cp "$item" "$web_dir/vnc_real.html" 2>/dev/null
            elif [ ! -e "$web_dir/$basename" ]; then
                ln -sf "$item" "$web_dir/$basename" 2>/dev/null || cp -r "$item" "$web_dir/$basename" 2>/dev/null
            fi
        done
        
        # Add auth check to vnc_real.html by prepending security script
        if [ -f "$web_dir/vnc_real.html" ]; then
            # Create temp file with security header
            cat > "$web_dir/vnc_real_secure.html" <<'EOFSECHEADER'
<!DOCTYPE html>
<html>
<head>
<script>
// SECURITY: Final auth check before VNC loads
(function() {
    const AUTH_ENABLED = 'AUTH_ENABLED_PLACEHOLDER';
    const VNC_USERNAME = 'VNC_USERNAME_PLACEHOLDER';
    const VNC_PASSWORD = 'VNC_PASSWORD_PLACEHOLDER';
    
    if (AUTH_ENABLED === 'true') {
        const authData = sessionStorage.getItem('vnc_auth');
        if (!authData) {
            window.location.replace('/login.html');
            throw new Error('No auth');
        }
        
        try {
            const decoded = atob(authData);
            const [user, pass] = decoded.split(':');
            if (user !== VNC_USERNAME || pass !== VNC_PASSWORD) {
                sessionStorage.clear();
                window.location.replace('/login.html');
                throw new Error('Invalid');
            }
        } catch (e) {
            sessionStorage.clear();
            window.location.replace('/login.html');
            throw new Error('Error');
        }
    }
})();
</script>
EOFSECHEADER
            
            # Extract body content from original vnc.html and append
            sed -n '/<head>/,/<\/head>/p' "$web_dir/vnc_real.html" | grep -v '<head>' | grep -v '</head>' >> "$web_dir/vnc_real_secure.html"
            echo '</head>' >> "$web_dir/vnc_real_secure.html"
            sed -n '/<body>/,/<\/html>/p' "$web_dir/vnc_real.html" >> "$web_dir/vnc_real_secure.html"
            
            # Replace original with secured version
            mv "$web_dir/vnc_real_secure.html" "$web_dir/vnc_real.html"
        fi
    fi
    
    # Create vnc_original.html as a protected wrapper
    cat > "$web_dir/vnc_original.html" <<'EOFVNCORIGINAL'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>VNC - VM_NAME_PLACEHOLDER</title>
    <script>
        // SECURITY: Block direct access - must come from vnc.html
        (function() {
            const AUTH_ENABLED = 'AUTH_ENABLED_PLACEHOLDER';
            const VNC_USERNAME = 'VNC_USERNAME_PLACEHOLDER';
            const VNC_PASSWORD = 'VNC_PASSWORD_PLACEHOLDER';
            
            if (AUTH_ENABLED === 'true') {
                const authData = sessionStorage.getItem('vnc_auth');
                if (!authData) {
                    window.location.replace('/login.html');
                    throw new Error('Auth required');
                }
                
                try {
                    const decoded = atob(authData);
                    const [user, pass] = decoded.split(':');
                    if (user !== VNC_USERNAME || pass !== VNC_PASSWORD) {
                        sessionStorage.clear();
                        window.location.replace('/login.html');
                        throw new Error('Invalid auth');
                    }
                } catch (e) {
                    sessionStorage.clear();
                    window.location.replace('/login.html');
                    throw new Error('Auth error');
                }
            }
            
            // Auth passed - load real VNC
            window.location.replace('/vnc_real.html' + window.location.search);
        })();
    </script>
</head>
<body>
    <div style="text-align:center; padding:50px; font-family:sans-serif;">
        <p>🔐 Verifying credentials...</p>
    </div>
</body>
</html>
EOFVNCORIGINAL
    
    # Create protected vnc.html that checks authentication BEFORE loading anything
    cat > "$web_dir/vnc.html" <<'EOFVNCHTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>VNC Console - VM_NAME_PLACEHOLDER</title>
    <script>
        // ULTRA SECURE: Check auth IMMEDIATELY before ANY content loads
        (function() {
            const AUTH_ENABLED = 'AUTH_ENABLED_PLACEHOLDER';
            const VNC_USERNAME = 'VNC_USERNAME_PLACEHOLDER';
            const VNC_PASSWORD = 'VNC_PASSWORD_PLACEHOLDER';
            
            function checkAuth() {
                if (AUTH_ENABLED !== 'true') {
                    return true; // No auth required
                }
                
                const authData = sessionStorage.getItem('vnc_auth');
                if (!authData) {
                    return false;
                }
                
                try {
                    const decoded = atob(authData);
                    const [user, pass] = decoded.split(':');
                    return user === VNC_USERNAME && pass === VNC_PASSWORD;
                } catch (e) {
                    return false;
                }
            }
            
            // Block page load if not authenticated
            if (!checkAuth()) {
                sessionStorage.setItem('vnc_return_url', window.location.pathname + window.location.search);
                window.location.replace('/login.html');
                // Stop script execution
                throw new Error('Authentication required');
            }
        })();
    </script>
    <script src="/auth.js"></script>
</head>
<body style="margin:0; padding:0; overflow:hidden;">
    <iframe id="vncFrame" src="/vnc_original.html" style="width:100%; height:100vh; border:none; display:none;"></iframe>
    <div id="loading" style="text-align:center; padding:50px; font-family:sans-serif;">
        <p>🔒 Verifying authentication...</p>
        <p style="color:#666; font-size:14px; margin-top:10px;">Loading VNC console...</p>
    </div>
    <script>
        // Double-check auth before showing iframe
        if (isAuthenticated()) {
            document.getElementById('vncFrame').style.display = 'block';
            document.getElementById('loading').style.display = 'none';
            
            // Add query parameters to iframe
            const params = new URLSearchParams(window.location.search);
            if (!params.has('autoconnect')) {
                params.set('autoconnect', 'true');
            }
            if (!params.has('resize')) {
                params.set('resize', 'scale');
            }
            document.getElementById('vncFrame').src = '/vnc_original.html?' + params.toString();
        } else {
            window.location.replace('/login.html');
        }
    </script>
</body>
</html>
EOFVNCHTML
    
    # Create authentication JavaScript library
    cat > "$web_dir/auth.js" <<'EOFAUTH'
// VNC Authentication System
const AUTH_ENABLED = 'AUTH_ENABLED_PLACEHOLDER';
const VNC_USERNAME = 'VNC_USERNAME_PLACEHOLDER';
const VNC_PASSWORD = 'VNC_PASSWORD_PLACEHOLDER';

function isAuthenticated() {
    if (AUTH_ENABLED !== 'true') return true;
    
    const authData = sessionStorage.getItem('vnc_auth');
    if (!authData) return false;
    
    try {
        const decoded = atob(authData);
        const [user, pass] = decoded.split(':');
        return user === VNC_USERNAME && pass === VNC_PASSWORD;
    } catch (e) {
        return false;
    }
}

function requireAuth(currentPage) {
    if (currentPage === '/login.html' || currentPage === 'login.html') {
        return true; // Allow access to login page
    }
    
    if (!isAuthenticated()) {
        sessionStorage.setItem('vnc_return_url', window.location.pathname + window.location.search);
        window.location.href = '/login.html';
        return false;
    }
    return true;
}

function doLogin(username, password) {
    if (AUTH_ENABLED !== 'true') return true;
    
    if (username === VNC_USERNAME && password === VNC_PASSWORD) {
        const authToken = btoa(username + ':' + password);
        sessionStorage.setItem('vnc_auth', authToken);
        sessionStorage.setItem('vnc_authenticated', 'true');
        return true;
    }
    return false;
}

function doLogout() {
    sessionStorage.clear();
    window.location.href = '/login.html';
}
EOFAUTH

    # Create index.html with auth protection
    cat > "$web_dir/index.html" <<'EOFINDEX'
<!DOCTYPE html>
<html>
<head>
    <title>VM Control Panel - VM_NAME_PLACEHOLDER</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="/auth.js"></script>
    <script>
        // Check auth IMMEDIATELY before page loads
        if (!requireAuth(window.location.pathname)) {
            // Will redirect to login
        }
    </script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 500px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
            text-align: center;
        }
        .vm-name {
            color: #667eea;
            font-size: 20px;
            text-align: center;
            margin-bottom: 30px;
            font-weight: 600;
        }
        .logout-btn {
            float: right;
            padding: 8px 16px;
            background: #ef4444;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            margin-bottom: 20px;
        }
        .logout-btn:hover { background: #dc2626; }
        .status {
            background: #f0f0f0;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
            clear: both;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        .status-running { background: #10b981; }
        .status-stopped { background: #ef4444; }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .buttons {
            display: grid;
            gap: 15px;
            margin-bottom: 20px;
        }
        button {
            padding: 15px 30px;
            font-size: 16px;
            font-weight: 600;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            transition: all 0.3s;
            color: white;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .btn-start { background: linear-gradient(135deg, #10b981, #059669); }
        .btn-stop { background: linear-gradient(135deg, #ef4444, #dc2626); }
        .btn-restart { background: linear-gradient(135deg, #f59e0b, #d97706); }
        .btn-vnc { background: linear-gradient(135deg, #667eea, #764ba2); }
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none !important;
        }
        .message {
            padding: 12px;
            border-radius: 8px;
            margin-top: 15px;
            text-align: center;
            display: none;
        }
        .message.success { background: #d1fae5; color: #065f46; display: block; }
        .message.error { background: #fee2e2; color: #991b1b; display: block; }
        .message.info { background: #dbeafe; color: #1e40af; display: block; }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <button class="logout-btn" onclick="doLogout()" id="logoutBtn" style="display:none;">🚪 Logout</button>
        
        <h1>🖥️ VM Control Panel</h1>
        <div class="vm-name">VM_NAME_PLACEHOLDER</div>
        
        <div class="status">
            <span class="status-indicator status-running" id="statusIndicator"></span>
            <span id="statusText">Checking status...</span>
        </div>
        
        <div class="buttons">
            <button class="btn-vnc" onclick="openVNC()">🖱️ Open VNC Console</button>
            <button class="btn-start" id="btnStart" onclick="controlVM('start')">▶️ Start VM</button>
            <button class="btn-stop" id="btnStop" onclick="controlVM('stop')">⏹️ Stop VM</button>
            <button class="btn-restart" id="btnRestart" onclick="controlVM('restart')">🔄 Restart VM</button>
        </div>
        
        <div class="message" id="message"></div>
        
        <div class="footer">
            VM Manager
        </div>
    </div>
    
    <script>
        const VM_NAME = 'VM_NAME_PLACEHOLDER';
        
        // Show logout button if auth enabled
        if (AUTH_ENABLED === 'true') {
            document.getElementById('logoutBtn').style.display = 'block';
        }
        
        function showMessage(text, type) {
            const msg = document.getElementById('message');
            msg.textContent = text;
            msg.className = 'message ' + type;
            setTimeout(() => { msg.style.display = 'none'; }, 5000);
        }
        
        function updateStatus(isRunning) {
            const indicator = document.getElementById('statusIndicator');
            const text = document.getElementById('statusText');
            const btnStart = document.getElementById('btnStart');
            const btnStop = document.getElementById('btnStop');
            const btnRestart = document.getElementById('btnRestart');
            
            if (isRunning) {
                indicator.className = 'status-indicator status-running';
                text.textContent = 'VM is Running';
                btnStart.disabled = true;
                btnStop.disabled = false;
                btnRestart.disabled = false;
            } else {
                indicator.className = 'status-indicator status-stopped';
                text.textContent = 'VM is Stopped';
                btnStart.disabled = false;
                btnStop.disabled = true;
                btnRestart.disabled = true;
            }
        }
        
        async function checkStatus() {
            try {
                const response = await fetch('/api/status/' + VM_NAME);
                const data = await response.json();
                updateStatus(data.running);
            } catch (error) {
                updateStatus(true);
            }
        }
        
        async function controlVM(action) {
            showMessage('Executing ' + action + '...', 'info');
            try {
                const response = await fetch('/api/vm/' + VM_NAME + '/' + action, { method: 'POST' });
                if (response.ok) {
                    showMessage(action.charAt(0).toUpperCase() + action.slice(1) + ' command sent!', 'success');
                    setTimeout(checkStatus, 2000);
                } else {
                    showMessage('Failed. Use main script: ./vms.sh', 'error');
                }
            } catch (error) {
                showMessage('API not available. Use: ./vms.sh', 'error');
            }
        }
        
        function openVNC() {
            window.location.href = '/vnc_secure.html';
        }
        
        checkStatus();
        setInterval(checkStatus, 5000);
    </script>
</body>
</html>
EOFINDEX
    
    # Create control panel HTML with auth protection
    cat > "$web_dir/control.html" <<'EOFCONTROL'
<!DOCTYPE html>
<html>
<head>
    <title>VM Control - VM_NAME_PLACEHOLDER</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="/auth.js"></script>
    <script>
        // Check auth IMMEDIATELY
        if (!requireAuth(window.location.pathname)) {
            // Will redirect to login
        }
    </script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .logout-btn {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 8px 16px;
            background: #ef4444;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            z-index: 1000;
        }
        .logout-btn:hover { background: #dc2626; }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { color: #333; text-align: center; margin-bottom: 30px; }
        .btn { 
            width: 100%;
            padding: 15px;
            margin: 10px 0;
            border: none;
            border-radius: 10px;
            color: white;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(0,0,0,0.2); }
        .btn-vnc { background: linear-gradient(135deg, #667eea, #764ba2); }
        .btn-home { background: linear-gradient(135deg, #10b981, #059669); }
    </style>
</head>
<body>
    <button class="logout-btn" onclick="doLogout()" id="logoutBtn" style="display:none;">🚪 Logout</button>
    <div class="container">
        <h1>🖥️ VM_NAME_PLACEHOLDER</h1>
        <button class="btn btn-vnc" onclick="window.location.href='/vnc_secure.html'">🖱️ Open VNC Console</button>
        <button class="btn btn-home" onclick="window.location.href='/'">🏠 Control Panel</button>
    </div>
    <script>
        if (AUTH_ENABLED === 'true') {
            document.getElementById('logoutBtn').style.display = 'block';
        }
    </script>
</body>
</html>
EOFCONTROL
    
    # Create login page for VNC authentication
    cat > "$web_dir/login.html" <<'EOFLOGIN'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Login - VM_NAME_PLACEHOLDER</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="/auth.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .login-container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 400px;
            width: 100%;
        }
        h1 { color: #333; margin-bottom: 10px; font-size: 28px; text-align: center; }
        .vm-name { color: #667eea; font-size: 18px; text-align: center; margin-bottom: 30px; font-weight: 600; }
        .lock-icon { text-align: center; font-size: 48px; margin-bottom: 20px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; color: #555; font-weight: 600; margin-bottom: 8px; font-size: 14px; }
        input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus { outline: none; border-color: #667eea; }
        button {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        button:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4); }
        button:active { transform: translateY(0); }
        .error {
            background: #fee2e2;
            color: #991b1b;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            text-align: center;
            font-weight: 500;
            display: none;
        }
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="lock-icon">🔒</div>
        <h1>VNC Authentication</h1>
        <div class="vm-name">VM_NAME_PLACEHOLDER</div>
        
        <div class="error" id="error">❌ Invalid username or password</div>
        
        <form id="loginForm" onsubmit="return handleLogin(event)">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" id="username" name="username" required autocomplete="username" autofocus>
            </div>
            
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required autocomplete="current-password">
            </div>
            
            <button type="submit">🚀 Access VNC Console</button>
        </form>
        
        <div class="footer">
            VM Manager
        </div>
    </div>
    
    <script>
        // Check if already authenticated
        if (isAuthenticated()) {
            const returnUrl = sessionStorage.getItem('vnc_return_url') || '/vnc_original.html?autoconnect=true&resize=scale';
            sessionStorage.removeItem('vnc_return_url');
            window.location.href = returnUrl;
        }
        
        function handleLogin(event) {
            event.preventDefault();
            
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('error');
            
            if (doLogin(username, password)) {
                // Login successful
                const returnUrl = sessionStorage.getItem('vnc_return_url') || '/vnc_original.html?autoconnect=true&resize=scale';
                sessionStorage.removeItem('vnc_return_url');
                window.location.href = returnUrl;
            } else {
                // Login failed
                errorDiv.style.display = 'block';
                document.getElementById('password').value = '';
                document.getElementById('password').focus();
                setTimeout(() => { errorDiv.style.display = 'none'; }, 3000);
            }
            
            return false;
        }
    </script>
</body>
</html>
EOFLOGIN
    
    # Create VNC wrapper with authentication check
    cat > "$web_dir/vnc_secure.html" <<'EOFVNCSECURE'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Console - VM_NAME_PLACEHOLDER</title>
    <meta charset="utf-8">
    <script src="/auth.js"></script>
    <script>
        // Check auth and redirect
        if (!requireAuth(window.location.pathname)) {
            // Will redirect to login
        } else {
            // Authenticated, go to VNC
            window.location.href = '/vnc_original.html?autoconnect=true&resize=scale';
        }
    </script>
</head>
<body>
    <p style="text-align:center; padding:50px; font-family:sans-serif;">Loading VNC console...</p>
</body>
</html>
EOFVNCSECURE
    
    # Set authentication variables
    local auth_enabled="false"
    local vnc_user=""
    local vnc_pass=""
    
    if [ -n "$VNC_USERNAME" ] && [ -n "$VNC_PASSWORD" ]; then
        auth_enabled="true"
        vnc_user="$VNC_USERNAME"
        vnc_pass="$VNC_PASSWORD"
    fi
    
    # Replace placeholders using reliable temp file method
    # For auth.js
    sed "s/AUTH_ENABLED_PLACEHOLDER/$auth_enabled/g; s/VNC_USERNAME_PLACEHOLDER/$vnc_user/g; s/VNC_PASSWORD_PLACEHOLDER/$vnc_pass/g" \
        "$web_dir/auth.js" > "$web_dir/auth.js.new" && mv "$web_dir/auth.js.new" "$web_dir/auth.js"
    
    # For vnc.html
    sed "s/VM_NAME_PLACEHOLDER/$vm_name/g; s/AUTH_ENABLED_PLACEHOLDER/$auth_enabled/g; s/VNC_USERNAME_PLACEHOLDER/$vnc_user/g; s/VNC_PASSWORD_PLACEHOLDER/$vnc_pass/g" \
        "$web_dir/vnc.html" > "$web_dir/vnc.html.new" && mv "$web_dir/vnc.html.new" "$web_dir/vnc.html"
    
    # For vnc_real.html (if it exists)
    if [ -f "$web_dir/vnc_real.html" ]; then
        sed "s/AUTH_ENABLED_PLACEHOLDER/$auth_enabled/g; s/VNC_USERNAME_PLACEHOLDER/$vnc_user/g; s/VNC_PASSWORD_PLACEHOLDER/$vnc_pass/g" \
            "$web_dir/vnc_real.html" > "$web_dir/vnc_real.html.new" && mv "$web_dir/vnc_real.html.new" "$web_dir/vnc_real.html"
    fi
    
    # For vnc_original.html
    sed "s/VM_NAME_PLACEHOLDER/$vm_name/g; s/AUTH_ENABLED_PLACEHOLDER/$auth_enabled/g; s/VNC_USERNAME_PLACEHOLDER/$vnc_user/g; s/VNC_PASSWORD_PLACEHOLDER/$vnc_pass/g" \
        "$web_dir/vnc_original.html" > "$web_dir/vnc_original.html.new" && mv "$web_dir/vnc_original.html.new" "$web_dir/vnc_original.html"
    
    # For login.html
    sed "s/VM_NAME_PLACEHOLDER/$vm_name/g" \
        "$web_dir/login.html" > "$web_dir/login.html.new" && mv "$web_dir/login.html.new" "$web_dir/login.html"
    
    # For index.html
    sed "s/VM_NAME_PLACEHOLDER/$vm_name/g" \
        "$web_dir/index.html" > "$web_dir/index.html.new" && mv "$web_dir/index.html.new" "$web_dir/index.html"
    
    # For vnc_secure.html
    sed "s/VM_NAME_PLACEHOLDER/$vm_name/g" \
        "$web_dir/vnc_secure.html" > "$web_dir/vnc_secure.html.new" && mv "$web_dir/vnc_secure.html.new" "$web_dir/vnc_secure.html"
    
    # For control.html
    sed "s/VM_NAME_PLACEHOLDER/$vm_name/g" \
        "$web_dir/control.html" > "$web_dir/control.html.new" && mv "$web_dir/control.html.new" "$web_dir/control.html"
    
    # Create simple API endpoint script
    cat > "$web_dir/api.sh" <<EOFAPI
#!/bin/bash
# Simple API for VM control
VM_NAME="$vm_name"
VM_DIR="$VM_DIR"

case "\$1" in
    status)
        if pgrep -f "vm-\$VM_NAME" >/dev/null 2>&1; then
            echo '{"running":true}'
        else
            echo '{"running":false}'
        fi
        ;;
    start)
        cd "$VM_DIR/.." && ./vms.sh --start "\$VM_NAME" &
        echo '{"success":true}'
        ;;
    stop)
        cd "$VM_DIR/.." && ./vms.sh --stop "\$VM_NAME" &
        echo '{"success":true}'
        ;;
    restart)
        cd "$VM_DIR/.." && ./vms.sh --stop "\$VM_NAME" && sleep 3 && ./vms.sh --start "\$VM_NAME" &
        echo '{"success":true}'
        ;;
esac
EOFAPI
    
    chmod +x "$web_dir/api.sh"
}

# Trap Ctrl+C for graceful message (VMs keep running)
trap 'handle_interrupt' INT TERM

# =============================
# Enhanced Multi-VM Manager
# =============================

# Color codes
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly MAGENTA='\033[1;35m'
readonly CYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly RESET='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

# Global variables
KVM_AVAILABLE=false
VM_DIR="${VM_DIR:-$HOME/vms}"

# CPU Models available
declare -A CPU_MODELS=(
    # AMD Ryzen Desktop CPUs
    ["AMD Ryzen 9 7950X3D"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 9 7950X3D 16-Core Processor"
    ["AMD Ryzen 9 7950X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 9 7950X 16-Core Processor"
    ["AMD Ryzen 9 7900X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 9 7900X 12-Core Processor"
    ["AMD Ryzen 9 5950X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 9 5950X 16-Core Processor"
    ["AMD Ryzen 9 5900X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 9 5900X 12-Core Processor"
    ["AMD Ryzen 7 7800X3D"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 7 7800X3D 8-Core Processor"
    ["AMD Ryzen 7 7700X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 7 7700X 8-Core Processor"
    ["AMD Ryzen 7 5800X3D"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 7 5800X3D 8-Core Processor"
    ["AMD Ryzen 7 5800X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 7 5800X 8-Core Processor"
    ["AMD Ryzen 5 7600X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 5 7600X 6-Core Processor"
    ["AMD Ryzen 5 5600X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen 5 5600X 6-Core Processor"
    
    # AMD Threadripper CPUs
    ["AMD Ryzen Threadripper PRO 5995WX"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen Threadripper PRO 5995WX 64-Cores"
    ["AMD Ryzen Threadripper PRO 5975WX"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen Threadripper PRO 5975WX 32-Cores"
    ["AMD Ryzen Threadripper 3990X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen Threadripper 3990X 64-Core Processor"
    ["AMD Ryzen Threadripper 3970X"]="EPYC,vendor=AuthenticAMD,model-id=AMD Ryzen Threadripper 3970X 32-Core Processor"
    
    # AMD EPYC Server CPUs
    ["AMD EPYC 9654"]="EPYC,vendor=AuthenticAMD,model-id=AMD EPYC 9654 96-Core Processor"
    ["AMD EPYC 9554"]="EPYC,vendor=AuthenticAMD,model-id=AMD EPYC 9554 64-Core Processor"
    ["AMD EPYC 7763"]="EPYC,vendor=AuthenticAMD,model-id=AMD EPYC 7763 64-Core Processor"
    ["AMD EPYC 7713"]="EPYC,vendor=AuthenticAMD,model-id=AMD EPYC 7713 64-Core Processor"
    ["AMD EPYC 7543"]="EPYC,vendor=AuthenticAMD,model-id=AMD EPYC 7543 32-Core Processor"
    ["AMD EPYC 7443"]="EPYC,vendor=AuthenticAMD,model-id=AMD EPYC 7443 24-Core Processor"
    
    # Intel Core Desktop CPUs (Latest Gen)
    ["Intel Core i9-14900K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i9-14900K"
    ["Intel Core i9-14900KS"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i9-14900KS"
    ["Intel Core i9-13900K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i9-13900K"
    ["Intel Core i9-13900KS"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i9-13900KS"
    ["Intel Core i9-12900K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i9-12900K"
    ["Intel Core i7-14700K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i7-14700K"
    ["Intel Core i7-13700K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i7-13700K"
    ["Intel Core i7-12700K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i7-12700K"
    ["Intel Core i5-14600K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i5-14600K"
    ["Intel Core i5-13600K"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Core i5-13600K"
    
    # Intel Xeon Server CPUs
    ["Intel Xeon Platinum 8480+"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon Platinum 8480+"
    ["Intel Xeon Platinum 8380"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon Platinum 8380"
    ["Intel Xeon Gold 6348"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon Gold 6348"
    ["Intel Xeon Gold 6338"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon Gold 6338"
    ["Intel Xeon Silver 4314"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon Silver 4314"
    ["Intel Xeon E5-2690 v4"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon E5-2690 v4"
    ["Intel Xeon E5-2680 v4"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon E5-2680 v4"
    ["Intel Xeon E-2388G"]="Skylake-Server,vendor=GenuineIntel,model-id=Intel Xeon E-2388G"
    
    # Special Options
    ["Host CPU (Passthrough)"]="host"
    ["QEMU Default (qemu64)"]="qemu64"
    ["Custom CPU Model"]="custom"
)

# Function to check KVM availability
check_kvm_support() {
    if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        if command -v kvm-ok &> /dev/null; then
            if kvm-ok &> /dev/null; then
                KVM_AVAILABLE=true
                return 0
            fi
        else
            if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
                KVM_AVAILABLE=true
                return 0
            fi
        fi
    fi
    KVM_AVAILABLE=false
    return 1
}

# Function to display animated header with enhanced visuals
display_header() {
    clear
    
    # Animated gradient header
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
███████████                            █████   █████                     ████████
░░███░░░░░███                          ░░░███   ░░███                     ███░░░░███
 ░███    ░███  █████ ████ ████████      ░███    ░███  █████████████     ░░░    ░███
 ░██████████  ░░███ ░███ ░░███░░███     ░███    ░███ ░░███░░███░░███       ██████░
 ░███░░░░░███  ░███ ░███  ░███ ░███     ░░███   ███   ░███ ░███ ░███      ░░░░░░███
 ░███    ░███  ░███ ░███  ░███ ░███      ░░░█████░    ░███ ░███ ░███     ███   ░███
 █████   █████ ░░████████ ████ █████       ░░███      █████░███ █████   ░░████████
░░░░░   ░░░░░   ░░░░░░░░ ░░░░ ░░░░░         ░░░      ░░░░░ ░░░ ░░░░░     ░░░░░░░░
EOF
    echo -e "${RESET}"
    echo
    
    # System Status Bar
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════════════════╗${RESET}"
    
    # KVM Status
    if [ "$KVM_AVAILABLE" = true ]; then
        echo -e "${BOLD}${BLUE}║${RESET} ${GREEN}${BOLD}⚡ KVM:${RESET} ${GREEN}ENABLED${RESET}  ${DIM}│${RESET}  ${CYAN}Hardware Acceleration Active${RESET}                    ${BOLD}${BLUE}║${RESET}"
    else
        echo -e "${BOLD}${BLUE}║${RESET} ${YELLOW}${BOLD}⚠ KVM:${RESET} ${YELLOW}DISABLED${RESET} ${DIM}│${RESET}  ${YELLOW}Software Emulation Mode${RESET}                        ${BOLD}${BLUE}║${RESET}"
    fi
    
    # Running VMs Count
    local running_count=$(pgrep -f "vm-" 2>/dev/null | wc -l)
    local total_vms=$(find "$VM_DIR" -name "*.conf" 2>/dev/null | wc -l)
    
    if [ $running_count -gt 0 ]; then
        echo -e "${BOLD}${BLUE}║${RESET} ${GREEN}${BOLD}🖥 VMs:${RESET} ${GREEN}$running_count Running${RESET} ${DIM}│${RESET}  ${CYAN}Total: $total_vms${RESET}                                       ${BOLD}${BLUE}║${RESET}"
    else
        echo -e "${BOLD}${BLUE}║${RESET} ${DIM}${BOLD}🖥 VMs:${RESET} ${DIM}0 Running${RESET}   ${DIM}│${RESET}  ${CYAN}Total: $total_vms${RESET}                                       ${BOLD}${BLUE}║${RESET}"
    fi
    
    # System Info
    local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    local cpu_count=$(nproc)
    echo -e "${BOLD}${BLUE}║${RESET} ${CYAN}${BOLD}💾 RAM:${RESET} ${CYAN}$mem_total${RESET}     ${DIM}│${RESET}  ${CYAN}${BOLD}🔧 CPUs:${RESET} ${CYAN}$cpu_count cores${RESET}                              ${BOLD}${BLUE}║${RESET}"
    
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# Function to display colored output with icons
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") 
            echo -e "${BLUE}${BOLD}[ℹ]${RESET} ${BLUE}$message${RESET}" 
            ;;
        "WARN") 
            echo -e "${YELLOW}${BOLD}[⚠]${RESET} ${YELLOW}$message${RESET}" 
            ;;
        "ERROR") 
            echo -e "${RED}${BOLD}[✗]${RESET} ${RED}$message${RESET}" 
            ;;
        "SUCCESS") 
            echo -e "${GREEN}${BOLD}[✓]${RESET} ${GREEN}$message${RESET}" 
            ;;
        "INPUT") 
            echo -ne "${CYAN}${BOLD}[?]${RESET} ${CYAN}$message${RESET}" 
            ;;
        "PROGRESS")
            echo -ne "${MAGENTA}${BOLD}[⟳]${RESET} ${MAGENTA}$message${RESET}\r"
            ;;
        *) 
            echo "[$type] $message" 
            ;;
    esac
}

# Function to safely read input with timeout
safe_read() {
    local prompt="$1"
    local default="${2:-}"
    local timeout="${3:-0}"
    local result
    
    if [ "$timeout" -gt 0 ]; then
        if read -t "$timeout" -p "$prompt" result 2>/dev/null; then
            echo "${result:-$default}"
        else
            echo "$default"
        fi
    else
        read -p "$prompt" result
        echo "${result:-$default}"
    fi
}

# Function to show spinner animation
show_spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr:i++%${#spinstr}:1}
        echo -ne "${MAGENTA}${BOLD}[$temp]${RESET} ${MAGENTA}$message${RESET}\r"
        sleep 0.1
    done
    echo -ne "\033[2K\r"
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Invalid input: Must be a positive number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMmTt]?$ ]]; then
                print_status "ERROR" "Invalid size format: Use format like 20G, 512M, or 20 (defaults to G)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Invalid port: Must be a number"
                return 1
            elif [ "$value" -lt 1024 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Invalid port range: Must be between 1024 and 65535"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "Invalid name: Use only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Invalid username: Must start with lowercase letter or underscore"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to normalize disk size
normalize_disk_size() {
    local size=$1
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "${size}G"
    else
        echo "$size"
    fi
}

# Function to check if port is available
check_port_available() {
    local port=$1
    if command -v ss &> /dev/null; then
        if ss -tln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img" "openssl")
    local missing_deps=()
    local optional_deps=("kvm-ok" "ss" "netstat" "uuidgen")
    
    print_status "INFO" "Checking system dependencies..."
    sleep 0.3
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            print_status "SUCCESS" "Found: $dep"
        else
            missing_deps+=("$dep")
            print_status "ERROR" "Missing: $dep"
        fi
    done
    
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            print_status "SUCCESS" "Found: $dep (optional)"
        else
            print_status "WARN" "Missing: $dep (optional)"
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo
        print_status "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        echo
        print_status "INFO" "Installation commands:"
        echo -e "${DIM}  Ubuntu/Debian: ${BOLD}sudo apt install qemu-system cloud-image-utils wget openssl${RESET}"
        echo -e "${DIM}  Fedora:        ${BOLD}sudo dnf install qemu-system-x86 cloud-utils wget openssl${RESET}"
        echo -e "${DIM}  Arch:          ${BOLD}sudo pacman -S qemu-full cloud-image-utils wget openssl${RESET}"
        echo
        exit 1
    fi
    
    print_status "SUCCESS" "All required dependencies are installed"
    
    # Check QEMU version and capabilities
    local qemu_version=$(qemu-system-x86_64 --version 2>/dev/null | head -1 | awk '{print $4}')
    if [ -n "$qemu_version" ]; then
        print_status "SUCCESS" "QEMU version: $qemu_version"
    fi
    
    sleep 0.3
}

# Function to cleanup temporary files
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Function to cleanup temp files only (VMs keep running)
cleanup_temp_files() {
    # Only clean up temporary files, don't touch VMs
    rm -f /tmp/vm-* 2>/dev/null || true
}

# Function to get all VM configurations
get_vm_list() {
    if [ ! -d "$VM_DIR" ]; then
        return
    fi
    find "$VM_DIR" -name "*.conf" -type f -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load VM configuration
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ ! -f "$config_file" ]]; then
        print_status "ERROR" "Configuration file not found: $config_file"
        return 1
    fi
    
    unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
    unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED CPU_MODEL CUSTOM_CPU_STRING
    unset VNC_PORT NOVNC_PORT SMBIOS_MANUFACTURER SMBIOS_PRODUCT SMBIOS_VERSION
    unset VNC_USERNAME VNC_PASSWORD
    
    if ! source "$config_file" 2>/dev/null; then
        print_status "ERROR" "Failed to load configuration from $config_file"
        return 1
    fi
    
    # Set default CPU model if not set
    CPU_MODEL="${CPU_MODEL:-Host CPU (Passthrough)}"
    
    # If custom CPU string exists, add it to CPU_MODELS for this session
    if [ -n "$CUSTOM_CPU_STRING" ] && [ -z "${CPU_MODELS[$CPU_MODEL]}" ]; then
        CPU_MODELS["$CPU_MODEL"]="$CUSTOM_CPU_STRING"
    fi
    
    if [[ -z "$VM_NAME" || -z "$IMG_FILE" ]]; then
        print_status "ERROR" "Invalid configuration: Missing required fields"
        return 1
    fi
    
    return 0
}

# Function to save VM configuration
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    # Get CPU string (handle custom CPUs)
    local cpu_string="${CPU_MODELS[$CPU_MODEL]}"
    if [ -z "$cpu_string" ] && [ -n "$CUSTOM_CPU_STRING" ]; then
        cpu_string="$CUSTOM_CPU_STRING"
    fi
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
VNC_PORT="${VNC_PORT:-}"
NOVNC_PORT="${NOVNC_PORT:-}"
VNC_USERNAME="${VNC_USERNAME:-}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
CPU_MODEL="$CPU_MODEL"
CUSTOM_CPU_STRING="$cpu_string"
SMBIOS_MANUFACTURER="${SMBIOS_MANUFACTURER:-VM}"
SMBIOS_PRODUCT="${SMBIOS_PRODUCT:-VM}"
SMBIOS_VERSION="${SMBIOS_VERSION:-1.0}"
AUTOSTART="false"
EOF
    
    if [ $? -eq 0 ]; then
        print_status "SUCCESS" "Configuration saved successfully"
    else
        print_status "ERROR" "Failed to save configuration"
        return 1
    fi
}

# Function to input custom CPU model
input_custom_cpu() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Custom CPU Model Configuration                        ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    print_status "INFO" "You can create a custom CPU model specification"
    echo
    echo -e "${DIM}Examples:${RESET}"
    echo -e "${DIM}  1. Simple: qemu64${RESET}"
    echo -e "${DIM}  2. AMD: EPYC,vendor=AuthenticAMD,model-id=My Custom AMD CPU${RESET}"
    echo -e "${DIM}  3. Intel: Skylake-Server,vendor=GenuineIntel,model-id=My Custom Intel CPU${RESET}"
    echo -e "${DIM}  4. With features: host,+ssse3,+sse4.1,+sse4.2${RESET}"
    echo
    
    echo -e "${BOLD}${YELLOW}Common CPU Base Types:${RESET}"
    echo -e "  ${CYAN}AMD:${RESET}   EPYC, EPYC-Rome, EPYC-Milan"
    echo -e "  ${CYAN}Intel:${RESET} Skylake-Server, Cascadelake-Server, Icelake-Server"
    echo -e "  ${CYAN}Other:${RESET} host, qemu64, max"
    echo
    
    while true; do
        read -p "$(print_status "INPUT" "Enter custom CPU string: ")" custom_cpu_string
        
        if [ -z "$custom_cpu_string" ]; then
            print_status "ERROR" "CPU string cannot be empty"
            continue
        fi
        
        # Basic validation
        if [[ "$custom_cpu_string" =~ ^[a-zA-Z0-9,+=._-]+$ ]]; then
            CUSTOM_CPU_STRING="$custom_cpu_string"
            
            # Ask for a friendly name
            read -p "$(print_status "INPUT" "Enter a friendly name for this CPU [${DIM}Custom CPU${RESET}]: ")" custom_cpu_name
            custom_cpu_name="${custom_cpu_name:-Custom CPU}"
            
            # Store in CPU_MODELS for this session
            CPU_MODELS["$custom_cpu_name"]="$custom_cpu_string"
            CPU_MODEL="$custom_cpu_name"
            
            print_status "SUCCESS" "Custom CPU model created: $custom_cpu_name"
            print_status "INFO" "CPU String: $custom_cpu_string"
            sleep 1
            break
        else
            print_status "ERROR" "Invalid CPU string format. Use only letters, numbers, and ,+=._- characters"
        fi
    done
}

# Function to select CPU model
select_cpu_model() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Select CPU Model                                      ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    # Organize CPUs by category
    local amd_desktop=()
    local amd_threadripper=()
    local amd_epyc=()
    local intel_desktop=()
    local intel_xeon=()
    local special=()
    
    for cpu in "${!CPU_MODELS[@]}"; do
        if [[ "$cpu" =~ "Ryzen 9" ]] || [[ "$cpu" =~ "Ryzen 7" ]] || [[ "$cpu" =~ "Ryzen 5" ]]; then
            amd_desktop+=("$cpu")
        elif [[ "$cpu" =~ "Threadripper" ]]; then
            amd_threadripper+=("$cpu")
        elif [[ "$cpu" =~ "EPYC" ]]; then
            amd_epyc+=("$cpu")
        elif [[ "$cpu" =~ "Core i" ]]; then
            intel_desktop+=("$cpu")
        elif [[ "$cpu" =~ "Xeon" ]]; then
            intel_xeon+=("$cpu")
        else
            special+=("$cpu")
        fi
    done
    
    # Sort arrays
    IFS=$'\n' amd_desktop=($(sort -r <<<"${amd_desktop[*]}")); unset IFS
    IFS=$'\n' amd_threadripper=($(sort -r <<<"${amd_threadripper[*]}")); unset IFS
    IFS=$'\n' amd_epyc=($(sort -r <<<"${amd_epyc[*]}")); unset IFS
    IFS=$'\n' intel_desktop=($(sort -r <<<"${intel_desktop[*]}")); unset IFS
    IFS=$'\n' intel_xeon=($(sort -r <<<"${intel_xeon[*]}")); unset IFS
    
    local cpu_options=()
    local i=1
    
    # Display AMD Desktop CPUs
    if [ ${#amd_desktop[@]} -gt 0 ]; then
        echo -e "${BOLD}${RED}AMD Ryzen Desktop CPUs:${RESET}"
        for cpu in "${amd_desktop[@]}"; do
            echo -e "  ${BOLD}$i)${RESET} ${GREEN}$cpu${RESET}"
            cpu_options[$i]="$cpu"
            ((i++))
        done
        echo
    fi
    
    # Display AMD Threadripper CPUs
    if [ ${#amd_threadripper[@]} -gt 0 ]; then
        echo -e "${BOLD}${RED}AMD Threadripper CPUs:${RESET}"
        for cpu in "${amd_threadripper[@]}"; do
            echo -e "  ${BOLD}$i)${RESET} ${GREEN}$cpu${RESET}"
            cpu_options[$i]="$cpu"
            ((i++))
        done
        echo
    fi
    
    # Display AMD EPYC CPUs
    if [ ${#amd_epyc[@]} -gt 0 ]; then
        echo -e "${BOLD}${RED}AMD EPYC Server CPUs:${RESET}"
        for cpu in "${amd_epyc[@]}"; do
            echo -e "  ${BOLD}$i)${RESET} ${GREEN}$cpu${RESET}"
            cpu_options[$i]="$cpu"
            ((i++))
        done
        echo
    fi
    
    # Display Intel Desktop CPUs
    if [ ${#intel_desktop[@]} -gt 0 ]; then
        echo -e "${BOLD}${BLUE}Intel Core Desktop CPUs:${RESET}"
        for cpu in "${intel_desktop[@]}"; do
            echo -e "  ${BOLD}$i)${RESET} ${GREEN}$cpu${RESET}"
            cpu_options[$i]="$cpu"
            ((i++))
        done
        echo
    fi
    
    # Display Intel Xeon CPUs
    if [ ${#intel_xeon[@]} -gt 0 ]; then
        echo -e "${BOLD}${BLUE}Intel Xeon Server CPUs:${RESET}"
        for cpu in "${intel_xeon[@]}"; do
            echo -e "  ${BOLD}$i)${RESET} ${GREEN}$cpu${RESET}"
            cpu_options[$i]="$cpu"
            ((i++))
        done
        echo
    fi
    
    # Display Special Options
    if [ ${#special[@]} -gt 0 ]; then
        echo -e "${BOLD}${MAGENTA}Special Options:${RESET}"
        for cpu in "${special[@]}"; do
            echo -e "  ${BOLD}$i)${RESET} ${CYAN}$cpu${RESET}"
            cpu_options[$i]="$cpu"
            ((i++))
        done
        echo
    fi
    
    local total_options=$((i-1))
    
    while true; do
        read -p "$(print_status "INPUT" "Select CPU model (1-$total_options) [${DIM}1${RESET}]: ")" choice
        choice="${choice:-1}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $total_options ]; then
            CPU_MODEL="${cpu_options[$choice]}"
            
            # If custom CPU selected, prompt for input
            if [[ "$CPU_MODEL" == "Custom CPU Model" ]]; then
                input_custom_cpu
            else
                print_status "SUCCESS" "Selected: $CPU_MODEL"
                sleep 0.3
            fi
            break
        else
            print_status "ERROR" "Invalid selection. Please try again."
        fi
    done
}

# Function to create new VM
create_new_vm() {
    echo
    print_status "INFO" "Starting VM creation wizard..."
    echo
    sleep 0.5
    
    # OS Selection
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Select Operating System           ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════╝${RESET}"
    echo
    
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        if [[ "$os" == "Proxmox VE 8" ]]; then
            echo -e "  ${BOLD}$i)${RESET} ${MAGENTA}${BOLD}$os${RESET} ${DIM}(Installer ISO)${RESET}"
        else
            echo -e "  ${BOLD}$i)${RESET} ${GREEN}$os${RESET}"
        fi
        os_options[$i]="$os"
        ((i++))
    done
    echo
    
    while true; do
        read -p "$(print_status "INPUT" "Enter your choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            print_status "SUCCESS" "Selected: $os"
            sleep 0.3
            break
        else
            print_status "ERROR" "Invalid selection. Please try again."
        fi
    done
    
    # Check if Proxmox
    local IS_PROXMOX=false
    if [[ "$OS_TYPE" == "proxmox" ]]; then
        IS_PROXMOX=true
    fi
    
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     VM Configuration                  ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════╝${RESET}"
    echo

    # VM Name
    while true; do
        read -p "$(print_status "INPUT" "VM name [${DIM}$DEFAULT_HOSTNAME${RESET}]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "VM '$VM_NAME' already exists. Choose a different name."
            else
                break
            fi
        fi
    done

    # Proxmox special handling - skip user/hostname/password
    if [ "$IS_PROXMOX" = true ]; then
        echo
        print_status "INFO" "Proxmox VE detected - Using installer mode"
        print_status "INFO" "You'll configure username/password during installation"
        HOSTNAME="$VM_NAME"
        USERNAME="root"
        PASSWORD="proxmox"
    else
        # Hostname
        while true; do
            read -p "$(print_status "INPUT" "Hostname [${DIM}$VM_NAME${RESET}]: ")" HOSTNAME
            HOSTNAME="${HOSTNAME:-$VM_NAME}"
            if validate_input "name" "$HOSTNAME"; then
                break
            fi
        done

        # Username
        while true; do
            read -p "$(print_status "INPUT" "Username [${DIM}$DEFAULT_USERNAME${RESET}]: ")" USERNAME
            USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
            if validate_input "username" "$USERNAME"; then
                break
            fi
        done

        # Password
        while true; do
            read -s -p "$(print_status "INPUT" "Password [${DIM}hidden${RESET}]: ")" PASSWORD
            PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
            echo
            if [ -n "$PASSWORD" ]; then
                break
            else
                print_status "ERROR" "Password cannot be empty"
            fi
        done
    fi

    # Disk size
    while true; do
        if [ "$IS_PROXMOX" = true ]; then
            read -p "$(print_status "INPUT" "Disk size [${DIM}32G${RESET}]: ")" DISK_SIZE
            DISK_SIZE="${DISK_SIZE:-32G}"
        else
            read -p "$(print_status "INPUT" "Disk size [${DIM}20G${RESET}]: ")" DISK_SIZE
            DISK_SIZE="${DISK_SIZE:-20G}"
        fi
        DISK_SIZE=$(normalize_disk_size "$DISK_SIZE")
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    # Memory
    while true; do
        if [ "$IS_PROXMOX" = true ]; then
            read -p "$(print_status "INPUT" "Memory in MB [${DIM}4096${RESET}]: ")" MEMORY
            MEMORY="${MEMORY:-4096}"
        else
            read -p "$(print_status "INPUT" "Memory in MB [${DIM}2048${RESET}]: ")" MEMORY
            MEMORY="${MEMORY:-2048}"
        fi
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    # CPUs
    while true; do
        if [ "$IS_PROXMOX" = true ]; then
            read -p "$(print_status "INPUT" "Number of CPUs [${DIM}4${RESET}]: ")" CPUS
            CPUS="${CPUS:-4}"
        else
            read -p "$(print_status "INPUT" "Number of CPUs [${DIM}2${RESET}]: ")" CPUS
            CPUS="${CPUS:-2}"
        fi
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    # CPU Model Selection
    select_cpu_model

    # SSH Port
    while true; do
        read -p "$(print_status "INPUT" "SSH Port [${DIM}2222${RESET}]: ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            if ! check_port_available "$SSH_PORT"; then
                print_status "ERROR" "Port $SSH_PORT is already in use"
            else
                break
            fi
        fi
    done

    # VNC/noVNC Port (for Proxmox and GUI mode)
    VNC_PORT=""
    NOVNC_PORT=""
    if [ "$IS_PROXMOX" = true ]; then
        echo
        print_status "INFO" "VNC/noVNC configuration for Proxmox web console"
        
        # Find next available VNC port
        local suggested_vnc=$(find_available_vnc_port 5900)
        
        # VNC Port
        while true; do
            read -p "$(print_status "INPUT" "VNC Port [${DIM}$suggested_vnc${RESET}]: ")" VNC_PORT
            VNC_PORT="${VNC_PORT:-$suggested_vnc}"
            if validate_input "port" "$VNC_PORT"; then
                # VNC ports must be 5900 or higher
                if [ "$VNC_PORT" -lt 5900 ]; then
                    print_status "ERROR" "VNC port must be 5900 or higher"
                    print_status "INFO" "VNC uses ports 5900+ (5900=display:0, 5901=display:1, etc.)"
                    continue
                fi
                if ! check_port_available "$VNC_PORT"; then
                    print_status "ERROR" "Port $VNC_PORT is already in use"
                    suggested_vnc=$(find_available_vnc_port $((VNC_PORT + 1)))
                    print_status "INFO" "Try next available port: $suggested_vnc"
                else
                    break
                fi
            fi
        done
        
        # Find next available noVNC port
        local suggested_novnc=$(find_available_novnc_port 6080)
        
        # noVNC Port
        while true; do
            read -p "$(print_status "INPUT" "noVNC Web Port [${DIM}$suggested_novnc${RESET}]: ")" NOVNC_PORT
            NOVNC_PORT="${NOVNC_PORT:-$suggested_novnc}"
            if validate_input "port" "$NOVNC_PORT"; then
                if ! check_port_available "$NOVNC_PORT"; then
                    print_status "ERROR" "Port $NOVNC_PORT is already in use"
                    suggested_novnc=$(find_available_novnc_port $((NOVNC_PORT + 1)))
                    print_status "INFO" "Try next available port: $suggested_novnc"
                else
                    break
                fi
            fi
        done
        
        GUI_MODE=true
    else
        # GUI Mode for other OSes
        while true; do
            read -p "$(print_status "INPUT" "Enable VNC/noVNC web console? (y/n) [${DIM}n${RESET}]: ")" gui_input
            GUI_MODE=false
            gui_input="${gui_input:-n}"
            if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
                GUI_MODE=true
                
                # Find next available VNC port
                local suggested_vnc=$(find_available_vnc_port 5900)
                
                # VNC Port
                while true; do
                    read -p "$(print_status "INPUT" "VNC Port [${DIM}$suggested_vnc${RESET}]: ")" VNC_PORT
                    VNC_PORT="${VNC_PORT:-$suggested_vnc}"
                    if validate_input "port" "$VNC_PORT"; then
                        # VNC ports must be 5900 or higher
                        if [ "$VNC_PORT" -lt 5900 ]; then
                            print_status "ERROR" "VNC port must be 5900 or higher"
                            print_status "INFO" "VNC uses ports 5900+ (5900=display:0, 5901=display:1, etc.)"
                            continue
                        fi
                        if ! check_port_available "$VNC_PORT"; then
                            print_status "ERROR" "Port $VNC_PORT is already in use"
                            suggested_vnc=$(find_available_vnc_port $((VNC_PORT + 1)))
                            print_status "INFO" "Try next available port: $suggested_vnc"
                        else
                            break
                        fi
                    fi
                done
                
                # Find next available noVNC port
                local suggested_novnc=$(find_available_novnc_port 6080)
                
                # noVNC Port
                while true; do
                    read -p "$(print_status "INPUT" "noVNC Web Port [${DIM}$suggested_novnc${RESET}]: ")" NOVNC_PORT
                    NOVNC_PORT="${NOVNC_PORT:-$suggested_novnc}"
                    if validate_input "port" "$NOVNC_PORT"; then
                        if ! check_port_available "$NOVNC_PORT"; then
                            print_status "ERROR" "Port $NOVNC_PORT is already in use"
                            suggested_novnc=$(find_available_novnc_port $((NOVNC_PORT + 1)))
                            print_status "INFO" "Try next available port: $suggested_novnc"
                        else
                            break
                        fi
                    fi
                done
                break
            elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                break
            else
                print_status "ERROR" "Please answer y or n"
            fi
        done
    fi

    # VNC Authentication (if VNC is enabled)
    VNC_USERNAME=""
    VNC_PASSWORD=""
    if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
        echo
        print_status "INFO" "VNC Authentication (optional but recommended)"
        
        read -p "$(print_status "INPUT" "Enable VNC password protection? (y/n) [${DIM}y${RESET}]: ")" vnc_auth
        vnc_auth="${vnc_auth:-y}"
        
        if [[ "$vnc_auth" =~ ^[Yy]$ ]]; then
            while true; do
                read -p "$(print_status "INPUT" "VNC Username [${DIM}admin${RESET}]: ")" VNC_USERNAME
                VNC_USERNAME="${VNC_USERNAME:-admin}"
                if validate_input "username" "$VNC_USERNAME"; then
                    break
                fi
            done
            
            while true; do
                read -s -p "$(print_status "INPUT" "VNC Password (min 6 chars): ")" VNC_PASSWORD
                echo
                if [ ${#VNC_PASSWORD} -ge 6 ]; then
                    read -s -p "$(print_status "INPUT" "Confirm VNC Password: ")" vnc_password_confirm
                    echo
                    if [ "$VNC_PASSWORD" = "$vnc_password_confirm" ]; then
                        break
                    else
                        print_status "ERROR" "Passwords do not match"
                    fi
                else
                    print_status "ERROR" "Password must be at least 6 characters"
                fi
            done
            
            print_status "SUCCESS" "VNC authentication enabled"
        else
            print_status "WARN" "VNC will be accessible without password (not recommended)"
        fi
    fi

    # Port forwards
    if [ "$IS_PROXMOX" = true ]; then
        # Proxmox web interface port
        read -p "$(print_status "INPUT" "Proxmox Web Port (host:guest) [${DIM}8006:8006${RESET}]: ")" proxmox_web
        proxmox_web="${proxmox_web:-8006:8006}"
        PORT_FORWARDS="$proxmox_web"
        
        read -p "$(print_status "INPUT" "Additional port forwards (e.g., 3128:3128) [${DIM}none${RESET}]: ")" additional_ports
        if [ -n "$additional_ports" ]; then
            PORT_FORWARDS="$PORT_FORWARDS,$additional_ports"
        fi
    else
        read -p "$(print_status "INPUT" "Additional port forwards (e.g., 8080:80,3000:3000) [${DIM}none${RESET}]: ")" PORT_FORWARDS
    fi

    # SMBIOS Branding Configuration
    echo
    print_status "INFO" "SMBIOS Branding (shown in VM as manufacturer/product info)"
    read -p "$(print_status "INPUT" "Manufacturer [${DIM}VM${RESET}]: ")" SMBIOS_MANUFACTURER
    SMBIOS_MANUFACTURER="${SMBIOS_MANUFACTURER:-VM}"
    
    read -p "$(print_status "INPUT" "Product Name [${DIM}VM${RESET}]: ")" SMBIOS_PRODUCT
    SMBIOS_PRODUCT="${SMBIOS_PRODUCT:-VM}"
    
    read -p "$(print_status "INPUT" "Version [${DIM}1.0${RESET}]: ")" SMBIOS_VERSION
    SMBIOS_VERSION="${SMBIOS_VERSION:-1.0}"

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    echo
    print_status "INFO" "Setting up VM image..."
    if [ "$IS_PROXMOX" = true ]; then
        setup_proxmox_vm
    else
        setup_vm_image
    fi
    
    echo
    save_vm_config
    
    echo
    print_status "SUCCESS" "VM '$VM_NAME' created successfully!"
    
    if [ "$IS_PROXMOX" = true ]; then
        echo
        print_status "INFO" "Proxmox VE Installation:"
        echo -e "  ${CYAN}1.${RESET} Start the VM to begin installation"
        echo -e "  ${CYAN}2.${RESET} Access via noVNC: ${BOLD}http://localhost:$NOVNC_PORT${RESET}"
        echo -e "  ${CYAN}3.${RESET} Follow Proxmox installer wizard"
        echo -e "  ${CYAN}4.${RESET} After install, access web UI: ${BOLD}https://localhost:8006${RESET}"
    fi
    
    sleep 2
}

# Function to setup VM image with ISO caching
setup_vm_image() {
    mkdir -p "$VM_DIR"
    mkdir -p "$VM_DIR/.iso_cache"  # Shared ISO cache directory
    
    # Determine cache file name based on OS type
    local cache_file="$VM_DIR/.iso_cache/${OS_TYPE}.img"
    
    # Check if cached ISO exists
    if [[ -f "$cache_file" ]]; then
        print_status "SUCCESS" "Using cached image for $OS_TYPE"
        
        # Copy from cache instead of downloading
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "INFO" "Copying from cache..."
            cp "$cache_file" "$IMG_FILE"
            print_status "SUCCESS" "Image copied from cache"
        else
            print_status "INFO" "Image file already exists"
        fi
    else
        # Download image (first time for this OS type)
        if [[ -f "$IMG_FILE" ]]; then
            print_status "INFO" "Image file already exists, skipping download"
        else
            print_status "INFO" "Downloading cloud image (first time for $OS_TYPE)..."
            echo -e "${DIM}  Source: $IMG_URL${RESET}"
            echo -e "${YELLOW}  Note: This will be cached for future VMs${RESET}"
            
            if wget --progress=bar:force:noscroll "$IMG_URL" -O "$IMG_FILE.tmp" 2>&1 | \
               while IFS= read -r line; do
                   if [[ $line =~ ([0-9]+)% ]]; then
                       echo -ne "${CYAN}${BOLD}[↓]${RESET} ${CYAN}Downloading... ${BOLD}${BASH_REMATCH[1]}%${RESET}\r"
                   fi
               done; then
                echo -ne "\033[2K\r"
                mv "$IMG_FILE.tmp" "$IMG_FILE"
                print_status "SUCCESS" "Download completed"
                
                # Save to cache for future use
                print_status "INFO" "Caching image for future VMs..."
                cp "$IMG_FILE" "$cache_file"
                print_status "SUCCESS" "Image cached successfully"
            else
                echo -ne "\033[2K\r"
                print_status "ERROR" "Failed to download image"
                rm -f "$IMG_FILE.tmp"
                return 1
            fi
        fi
    fi
    
    # Resize disk
    print_status "INFO" "Resizing disk to $DISK_SIZE..."
    if qemu-img resize "$IMG_FILE" "$DISK_SIZE" &>/dev/null; then
        print_status "SUCCESS" "Disk resized successfully"
    else
        print_status "WARN" "Could not resize existing image, creating new one..."
        if qemu-img create -f qcow2 "$IMG_FILE.new" "$DISK_SIZE" &>/dev/null; then
            mv "$IMG_FILE.new" "$IMG_FILE"
            print_status "SUCCESS" "New disk image created"
        else
            print_status "ERROR" "Failed to create disk image"
            return 1
        fi
    fi

    # Create cloud-init configuration
    print_status "INFO" "Generating cloud-init configuration..."
    
    local hashed_password
    if ! hashed_password=$(openssl passwd -6 "$PASSWORD" 2>/dev/null | tr -d '\n'); then
        print_status "ERROR" "Failed to hash password"
        return 1
    fi
    
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false

# Enable root login with password
ssh_authorized_keys: []
chpasswd:
  expire: false
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD

# Configure SSH to allow root login
ssh_deletekeys: false
ssh_genkeytypes: ['rsa', 'ecdsa', 'ed25519']

# Modify SSH config to allow root login
runcmd:
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd || systemctl restart ssh
  - echo "Root login enabled"

users:
  - name: root
    lock_passwd: false
    hashed_passwd: $hashed_password
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    hashed_passwd: $hashed_password
    groups: sudo,adm,dialout,cdrom,floppy,audio,dip,video,plugdev,netdev

package_update: true
package_upgrade: false

# Set timezone
timezone: UTC

# Final message
final_message: |
  VM is ready!
  Hostname: $HOSTNAME
  Root login: enabled
  User: $USERNAME
  SSH Port: $SSH_PORT (forwarded)
  Login: ssh root@localhost -p $SSH_PORT
  Or: ssh $USERNAME@localhost -p $SSH_PORT
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if cloud-localds "$SEED_FILE" user-data meta-data &>/dev/null; then
        print_status "SUCCESS" "Cloud-init seed created"
    else
        print_status "ERROR" "Failed to create cloud-init seed"
        return 1
    fi
}

# Function to setup Proxmox VM with ISO caching
setup_proxmox_vm() {
    mkdir -p "$VM_DIR"
    mkdir -p "$VM_DIR/.iso_cache"  # Shared ISO cache directory
    
    # Determine cache file name for Proxmox
    local cache_file="$VM_DIR/.iso_cache/proxmox-ve-8.iso"
    
    # Check if cached ISO exists
    if [[ -f "$cache_file" ]]; then
        print_status "SUCCESS" "Using cached Proxmox ISO"
        
        # Copy from cache instead of downloading
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "INFO" "Copying from cache..."
            cp "$cache_file" "$IMG_FILE"
            print_status "SUCCESS" "ISO copied from cache"
        else
            print_status "INFO" "Proxmox ISO already exists"
        fi
    else
        # Download Proxmox ISO (first time)
        if [[ -f "$IMG_FILE" ]]; then
            print_status "INFO" "Proxmox ISO already exists, skipping download"
        else
            print_status "INFO" "Downloading Proxmox VE ISO (first time)..."
            echo -e "${DIM}  Source: $IMG_URL${RESET}"
            echo -e "${YELLOW}  Note: This is a large file (~1GB), please be patient${RESET}"
            echo -e "${YELLOW}  This will be cached for future Proxmox VMs${RESET}"
            
            if wget --progress=bar:force:noscroll "$IMG_URL" -O "$IMG_FILE.tmp" 2>&1 | \
               while IFS= read -r line; do
                   if [[ $line =~ ([0-9]+)% ]]; then
                       echo -ne "${CYAN}${BOLD}[↓]${RESET} ${CYAN}Downloading Proxmox ISO... ${BOLD}${BASH_REMATCH[1]}%${RESET}\r"
                   fi
               done; then
                echo -ne "\033[2K\r"
                mv "$IMG_FILE.tmp" "$IMG_FILE"
                print_status "SUCCESS" "Download completed"
                
                # Save to cache for future use
                print_status "INFO" "Caching ISO for future Proxmox VMs..."
                cp "$IMG_FILE" "$cache_file"
                print_status "SUCCESS" "ISO cached successfully"
            else
                echo -ne "\033[2K\r"
                print_status "ERROR" "Failed to download Proxmox ISO"
                rm -f "$IMG_FILE.tmp"
                return 1
            fi
        fi
    fi
    
    # Create empty disk for Proxmox installation
    local proxmox_disk="$VM_DIR/$VM_NAME-disk.qcow2"
    print_status "INFO" "Creating virtual disk for Proxmox installation..."
    if qemu-img create -f qcow2 "$proxmox_disk" "$DISK_SIZE" &>/dev/null; then
        print_status "SUCCESS" "Virtual disk created: $DISK_SIZE"
    else
        print_status "ERROR" "Failed to create virtual disk"
        return 1
    fi
    
    # No cloud-init for Proxmox (installer mode)
    SEED_FILE=""
    
    print_status "SUCCESS" "Proxmox VM setup complete"
    print_status "INFO" "VM will boot from ISO installer"
}

# Function to start a VM
start_vm() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    print_status "INFO" "Starting VM: ${BOLD}$vm_name${RESET}"
    echo
    
    # Check if Proxmox (no cloud-init needed)
    local IS_PROXMOX=false
    if [[ "$OS_TYPE" == "proxmox" ]]; then
        IS_PROXMOX=true
        print_status "INFO" "Proxmox VE detected - Installer mode"
    fi
    
    # Verify files exist
    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "ERROR" "VM image not found: $IMG_FILE"
        echo
        print_status "INFO" "The VM may be corrupted. Try recreating it."
        sleep 2
        return 1
    fi
    
    # Only check seed file for non-Proxmox VMs
    if [ "$IS_PROXMOX" = false ]; then
        if [[ ! -f "$SEED_FILE" ]]; then
            print_status "WARN" "Seed file missing: $SEED_FILE"
            print_status "INFO" "Recreating seed file..."
            if ! setup_vm_image; then
                print_status "ERROR" "Failed to recreate seed file"
                sleep 2
                return 1
            fi
        fi
    fi
    
    # Check port availability
    if ! check_port_available "$SSH_PORT"; then
        print_status "ERROR" "Port $SSH_PORT is already in use!"
        print_status "INFO" "Use option 5 (Edit VM) to change the SSH port"
        sleep 2
        return 1
    fi
    
    # Display connection info
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║     Connection Information            ║${RESET}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════╝${RESET}"
    echo -e "  ${CYAN}SSH:${RESET}      ${BOLD}ssh -p $SSH_PORT $USERNAME@localhost${RESET}"
    echo -e "  ${CYAN}Username:${RESET} ${BOLD}$USERNAME${RESET}"
    echo -e "  ${CYAN}Password:${RESET} ${BOLD}$PASSWORD${RESET}"
    echo -e "  ${CYAN}CPU Model:${RESET} ${BOLD}$CPU_MODEL${RESET}"
    echo
    
    # Build QEMU command
    local qemu_cmd=(qemu-system-x86_64)
    
    # Detect available machine type
    local machine_type="pc"
    if command -v qemu-system-x86_64 &> /dev/null; then
        # Try to get a specific pc-i440fx version
        local available_machine=$(qemu-system-x86_64 -machine help 2>/dev/null | grep -E "^pc-i440fx" | head -1 | awk '{print $1}')
        if [ -n "$available_machine" ]; then
            machine_type="$available_machine"
        else
            # Fallback to generic 'pc' if no specific version found
            machine_type="pc"
        fi
    fi
    
    # Machine type with custom name
    qemu_cmd+=(-machine "$machine_type")
    qemu_cmd+=(-name "VM-$VM_NAME,process=vm-$VM_NAME")
    
    print_status "INFO" "Machine type: $machine_type"
    
    # KVM acceleration and CPU model
    if [ "$KVM_AVAILABLE" = true ]; then
        qemu_cmd+=(-enable-kvm)
        print_status "SUCCESS" "Using KVM hardware acceleration"
        
        # Apply CPU model
        local cpu_string="${CPU_MODELS[$CPU_MODEL]}"
        
        # If no CPU string found in models, use CUSTOM_CPU_STRING
        if [ -z "$cpu_string" ] && [ -n "$CUSTOM_CPU_STRING" ]; then
            cpu_string="$CUSTOM_CPU_STRING"
        fi
        
        # Fallback to host if still empty
        if [ -z "$cpu_string" ]; then
            cpu_string="host"
        fi
        
        qemu_cmd+=(-cpu "$cpu_string")
        print_status "INFO" "CPU Model: $CPU_MODEL"
        
        # Show custom CPU string if it's a custom model
        if [ -n "$CUSTOM_CPU_STRING" ] && [[ ! "$CPU_MODEL" =~ ^(Host CPU|QEMU Default).*$ ]]; then
            print_status "INFO" "CPU String: $cpu_string"
        fi
    else
        qemu_cmd+=(-cpu qemu64)
        print_status "WARN" "KVM not available, using software emulation (slower)"
        print_status "WARN" "Custom CPU model disabled in emulation mode"
    fi
    
    # Basic configuration - Different for Proxmox and ISO-based VMs
    qemu_cmd+=(
        -m "$MEMORY"
        -smp "$CPUS"
    )
    
    # Determine boot configuration
    # Universal smart boot detection for ALL OS types
    local is_first_boot=true
    local is_installing=false
    local boot_marker="$VM_DIR/.$VM_NAME.installed"
    local reboot_marker="$VM_DIR/.$VM_NAME.rebooted"
    local uptime_marker="$VM_DIR/.$VM_NAME.uptime"
    
    # Check if installation is complete AND VM has been rebooted
    if [ -f "$reboot_marker" ]; then
        # Installation complete and rebooted - detach ISO
        is_first_boot=false
        is_installing=false
    elif [ -f "$boot_marker" ]; then
        # Installation in progress - check if this is a fresh reboot
        # If uptime marker exists and is recent (< 2 minutes old), this is a reboot
        if [ -f "$uptime_marker" ]; then
            local marker_age=$(($(date +%s) - $(stat -c%Y "$uptime_marker" 2>/dev/null || echo "0")))
            if [ "$marker_age" -gt 120 ]; then
                # Marker is old (> 2 minutes), this is likely a reboot after installation
                # Create reboot marker and proceed to detach ISO
                touch "$reboot_marker"
                is_first_boot=false
                is_installing=false
                print_status "SUCCESS" "Installation complete detected - ISO will be detached"
            else
                # Marker is fresh, still in same boot session
                is_first_boot=false
                is_installing=true
            fi
        else
            # No uptime marker yet, create it
            touch "$uptime_marker"
            is_first_boot=false
            is_installing=true
        fi
    else
        # First boot - need to install
        is_first_boot=true
        is_installing=false
    fi
    
    if [ "$IS_PROXMOX" = true ]; then
        # Proxmox: Smart boot order based on installation status
        local proxmox_disk="$VM_DIR/$VM_NAME-disk.qcow2"
        
        # Create disk if doesn't exist
        if [ ! -f "$proxmox_disk" ]; then
            print_status "INFO" "Creating Proxmox installation disk: $DISK_SIZE"
            qemu-img create -f qcow2 "$proxmox_disk" "$DISK_SIZE" >/dev/null 2>&1
        fi
        
        # Check Proxmox disk size to detect installation progress
        if [ -f "$proxmox_disk" ]; then
            local proxmox_disk_size=$(stat -f%z "$proxmox_disk" 2>/dev/null || stat -c%s "$proxmox_disk" 2>/dev/null || echo "0")
            # If disk is larger than 1GB, installation has started/completed
            if [ "$proxmox_disk_size" -gt 1000000000 ] && [ ! -f "$boot_marker" ]; then
                touch "$boot_marker"
                touch "$uptime_marker"
                print_status "INFO" "Installation detected - marker created"
            fi
        fi
        
        if [ "$is_first_boot" = true ]; then
            # First boot - boot from ISO with disk attached
            qemu_cmd+=(
                -drive "file=$IMG_FILE,media=cdrom,readonly=on,index=0"
                -drive "file=$proxmox_disk,format=qcow2,if=virtio,cache=writeback,index=1"
                -boot order=d,menu=on
            )
            print_status "INFO" "First boot - Booting from ISO installer"
            print_status "INFO" "Boot order: CD-ROM → Disk"
            print_status "WARN" "After installation completes, reboot VM from Proxmox installer"
        elif [ "$is_installing" = true ]; then
            # Installation in progress or just completed - keep ISO attached
            qemu_cmd+=(
                -drive "file=$IMG_FILE,media=cdrom,readonly=on,index=0"
                -drive "file=$proxmox_disk,format=qcow2,if=virtio,cache=writeback,index=1"
                -boot order=c,menu=on
            )
            print_status "INFO" "Installation phase - ISO still attached"
            print_status "INFO" "Boot order: Disk → CD-ROM (fallback)"
            print_status "WARN" "After installation completes and VM reboots, stop and start VM again"
            
            # Update uptime marker to track this boot session
            touch "$uptime_marker"
        else
            # Installation complete and rebooted - boot from disk only, NO ISO
            qemu_cmd+=(
                -drive "file=$proxmox_disk,format=qcow2,if=virtio,cache=writeback"
                -boot order=c,menu=on
            )
            print_status "SUCCESS" "Booting from installed system (ISO detached)"
            print_status "INFO" "Boot order: Disk only"
        fi
    else
        # Regular VMs: Check if this is a cloud-init image or custom ISO
        local has_iso=false
        
        # Check if IMG_FILE is an ISO (ends with .iso or is in .iso_cache)
        if [[ "$IMG_URL" == *".iso"* ]] || [[ "$IMG_FILE" == *".iso"* ]] || [[ "$IMG_FILE" == *".iso_cache"* ]]; then
            has_iso=true
        fi
        
        if [ "$has_iso" = true ]; then
            # Custom ISO installation
            local install_disk="$VM_DIR/$VM_NAME-disk.qcow2"
            
            # Create disk if doesn't exist
            if [ ! -f "$install_disk" ]; then
                print_status "INFO" "Creating installation disk: $DISK_SIZE"
                qemu-img create -f qcow2 "$install_disk" "$DISK_SIZE" >/dev/null 2>&1
            fi
            
            # Check if disk has data (installation started/completed)
            if [ -f "$install_disk" ]; then
                local install_disk_size=$(stat -f%z "$install_disk" 2>/dev/null || stat -c%s "$install_disk" 2>/dev/null || echo "0")
                if [ "$install_disk_size" -gt 2000000000 ] && [ ! -f "$boot_marker" ]; then
                    touch "$boot_marker"
                    touch "$uptime_marker"
                    print_status "INFO" "Installation detected - marker created"
                fi
            fi
            
            if [ "$is_first_boot" = true ]; then
                # First boot - boot from ISO
                qemu_cmd+=(
                    -drive "file=$IMG_FILE,media=cdrom,readonly=on,index=0"
                    -drive "file=$install_disk,format=qcow2,if=virtio,cache=writeback,index=1"
                    -boot order=d,menu=on
                )
                print_status "INFO" "First boot - Booting from ISO installer"
                print_status "INFO" "Boot order: CD-ROM → Disk"
                print_status "WARN" "After installation completes, reboot VM from installer"
            elif [ "$is_installing" = true ]; then
                # Installation in progress or just completed - keep ISO attached
                qemu_cmd+=(
                    -drive "file=$IMG_FILE,media=cdrom,readonly=on,index=0"
                    -drive "file=$install_disk,format=qcow2,if=virtio,cache=writeback,index=1"
                    -boot order=c,menu=on
                )
                print_status "INFO" "Installation phase - ISO still attached"
                print_status "INFO" "Boot order: Disk → CD-ROM (fallback)"
                print_status "WARN" "After installation completes and VM reboots, stop and start VM again"
                
                # Update uptime marker to track this boot session
                touch "$uptime_marker"
            else
                # Installation complete and rebooted - boot from disk only, NO ISO
                qemu_cmd+=(
                    -drive "file=$install_disk,format=qcow2,if=virtio,cache=writeback"
                    -boot order=c,menu=on
                )
                print_status "SUCCESS" "Booting from installed system (ISO detached)"
                print_status "INFO" "Boot order: Disk only"
            fi
        else
            # Cloud-init image (pre-installed)
            qemu_cmd+=(
                -drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=writeback"
                -drive "file=$SEED_FILE,format=raw,if=virtio"
                -boot order=c,menu=on
            )
            print_status "INFO" "Booting from cloud-init image (pre-installed)"
            # Mark as installed since cloud images are pre-installed
            touch "$boot_marker"
        fi
    fi
    
    # Network with port forwards
    local network_config="user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
    
    # Add additional port forwards to the same network device
    if [[ -n "$PORT_FORWARDS" ]]; then
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        for forward in "${forwards[@]}"; do
            forward=$(echo "$forward" | xargs)  # Trim whitespace
            if [[ "$forward" =~ ^([0-9]+):([0-9]+)$ ]]; then
                local host_port="${BASH_REMATCH[1]}"
                local guest_port="${BASH_REMATCH[2]}"
                
                if check_port_available "$host_port"; then
                    network_config="$network_config,hostfwd=tcp::$host_port-:$guest_port"
                    print_status "INFO" "Port forward: $host_port -> $guest_port"
                else
                    print_status "WARN" "Port $host_port is in use, skipping forward $forward"
                fi
            else
                print_status "WARN" "Invalid port forward format: $forward (use HOST:GUEST)"
            fi
        done
    fi
    
    qemu_cmd+=(
        -device virtio-net-pci,netdev=n0
        -netdev "$network_config"
    )
    
    # SMBIOS customization - Use configured branding
    qemu_cmd+=(
        -smbios "type=0,vendor=${SMBIOS_MANUFACTURER:-VM},version=${SMBIOS_VERSION:-1.0},date=$(date +%m/%d/%Y)"
        -smbios "type=1,manufacturer=${SMBIOS_MANUFACTURER:-VM},product=${SMBIOS_PRODUCT:-VM},version=${SMBIOS_VERSION:-1.0},serial=$VM_NAME-$(date +%s),uuid=$(uuidgen 2>/dev/null || echo "00000000-0000-0000-0000-$(printf '%012d' $$)"),family=${SMBIOS_MANUFACTURER:-VM} Virtual Machine"
        -smbios "type=2,manufacturer=${SMBIOS_MANUFACTURER:-VM},product=${SMBIOS_PRODUCT:-VM} Motherboard,version=${SMBIOS_VERSION:-1.0},serial=MB-$VM_NAME"
        -smbios "type=3,manufacturer=${SMBIOS_MANUFACTURER:-VM},version=${SMBIOS_VERSION:-1.0}"
    )

    # VNC/Display mode
    if [ -n "$VNC_PORT" ]; then
        # VNC enabled - calculate display number
        # VNC ports should be 5900 or higher
        if [ "$VNC_PORT" -lt 5900 ]; then
            print_status "ERROR" "VNC port must be 5900 or higher (got $VNC_PORT)"
            print_status "INFO" "VNC display formula: port = 5900 + display_number"
            print_status "INFO" "Example: port 5900 = display :0, port 5901 = display :1"
            return 1
        fi
        
        local vnc_display=$((VNC_PORT - 5900))
        qemu_cmd+=(-vnc "0.0.0.0:$vnc_display")
        print_status "INFO" "VNC enabled on port $VNC_PORT (display :$vnc_display)"
    else
        # No VNC - background mode only
        qemu_cmd+=(-display none)
    fi
    
    qemu_cmd+=(-daemonize)
    
    # Create directories
    mkdir -p "$VM_DIR/pids"
    mkdir -p "$VM_DIR/logs"
    
    qemu_cmd+=(-pidfile "$VM_DIR/pids/$VM_NAME.pid")
    qemu_cmd+=(-serial "file:$VM_DIR/logs/$VM_NAME.log")
    
    # Performance enhancements
    qemu_cmd+=(
        -device virtio-balloon-pci
        -object rng-random,filename=/dev/urandom,id=rng0
        -device virtio-rng-pci,rng=rng0
    )
    
    # Add USB support for better compatibility
    qemu_cmd+=(
        -device qemu-xhci,id=xhci
        -device usb-tablet
    )
    
    # Add sound card for desktop VMs
    if [ "$IS_PROXMOX" = false ]; then
        qemu_cmd+=(
            -device intel-hda
            -device hda-duplex
        )
    fi

    echo
    if [ -n "$VNC_PORT" ]; then
        print_status "INFO" "Starting VM with VNC console..."
    else
        print_status "INFO" "Starting VM in background mode..."
    fi
    echo
    
    # Start VM in background
    if "${qemu_cmd[@]}" 2>>"$VM_DIR/logs/$VM_NAME.log"; then
        sleep 2
        
        # Verify it started
        if is_vm_running "$vm_name"; then
            print_status "SUCCESS" "VM '$vm_name' started successfully!"
            echo
            print_status "INFO" "VM is running in background"
            
            # Verify VNC port if configured
            if [ -n "$VNC_PORT" ]; then
                print_status "INFO" "Waiting for VNC server to be ready..."
                local vnc_ready=false
                local vnc_wait=0
                
                while [ $vnc_wait -lt 10 ]; do
                    if ss -tln 2>/dev/null | grep -q ":$VNC_PORT " || netstat -tln 2>/dev/null | grep -q ":$VNC_PORT "; then
                        vnc_ready=true
                        print_status "SUCCESS" "VNC server is listening on port $VNC_PORT"
                        break
                    fi
                    sleep 1
                    ((vnc_wait++))
                done
                
                if [ "$vnc_ready" = false ]; then
                    print_status "WARN" "VNC port $VNC_PORT not listening yet"
                    print_status "INFO" "VNC may take a few more seconds to start"
                    print_status "INFO" "Check with: ss -tln | grep $VNC_PORT"
                fi
            fi
            
            # Start noVNC if VNC is configured
            if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
                # Check if systemd service exists for this VM
                local vm_service_exists=false
                local novnc_service_exists=false
                
                if sudo systemctl list-unit-files "vm-${vm_name}.service" &>/dev/null 2>&1; then
                    vm_service_exists=true
                fi
                
                if sudo systemctl list-unit-files "vm-${vm_name}-novnc.service" &>/dev/null 2>&1; then
                    novnc_service_exists=true
                fi
                
                # If both services exist, use systemd for noVNC
                if [ "$vm_service_exists" = true ] && [ "$novnc_service_exists" = true ]; then
                    print_status "INFO" "noVNC managed by systemd service"
                    print_status "INFO" "Starting noVNC service..."
                    if sudo systemctl start "vm-${vm_name}-novnc.service" 2>/dev/null; then
                        sleep 2
                        if sudo systemctl is-active "vm-${vm_name}-novnc.service" &>/dev/null; then
                            print_status "SUCCESS" "noVNC service started"
                        else
                            print_status "WARN" "noVNC service failed, trying manual start..."
                            start_novnc_proxy "$vm_name" "$VNC_PORT" "$NOVNC_PORT"
                        fi
                    else
                        print_status "WARN" "noVNC service failed to start, trying manual start..."
                        start_novnc_proxy "$vm_name" "$VNC_PORT" "$NOVNC_PORT"
                    fi
                else
                    # No systemd services or incomplete setup - start manually
                    print_status "INFO" "Starting noVNC manually (systemd not configured)"
                    start_novnc_proxy "$vm_name" "$VNC_PORT" "$NOVNC_PORT"
                    
                    # Suggest enabling autostart for better management
                    echo
                    print_status "INFO" "Tip: Enable autostart for automatic noVNC management"
                    print_status "INFO" "Use: ${BOLD}6) Manage Autostart${RESET} from main menu"
                fi
            fi
            
            # Display connection info
            if [ "$IS_PROXMOX" = true ]; then
                echo
                print_status "INFO" "Proxmox VE Installation:"
                if [ -n "$NOVNC_PORT" ]; then
                    echo
                    echo -e "  ${GREEN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
                    echo -e "  ${GREEN}${BOLD}Web Console URL (copy this):${RESET}"
                    echo -e "  ${GREEN}${BOLD}http://localhost:$NOVNC_PORT/vnc.html${RESET}"
                    echo -e "  ${GREEN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
                    echo
                fi
                if [ -n "$VNC_PORT" ]; then
                    print_status "INFO" "VNC Client: ${BOLD}localhost:$VNC_PORT${RESET}"
                fi
                print_status "INFO" "After install: ${BOLD}https://localhost:8006${RESET}"
            else
                print_status "INFO" "SSH: ${BOLD}ssh $USERNAME@localhost -p $SSH_PORT${RESET}"
                print_status "INFO" "Or: ${BOLD}ssh root@localhost -p $SSH_PORT${RESET}"
                if [ -n "$NOVNC_PORT" ]; then
                    echo
                    echo -e "  ${GREEN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
                    echo -e "  ${GREEN}${BOLD}Web Console URL (copy this):${RESET}"
                    echo -e "  ${GREEN}${BOLD}http://localhost:$NOVNC_PORT/vnc.html${RESET}"
                    echo -e "  ${GREEN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
                    echo
                fi
            fi
            echo
            print_status "INFO" "View logs: tail -f $VM_DIR/logs/$VM_NAME.log"
            sleep 3
        else
            print_status "ERROR" "VM started but process not found"
            echo
            print_status "INFO" "Check log: $VM_DIR/logs/$VM_NAME.log"
        fi
    else
        print_status "ERROR" "Failed to start VM"
        echo
        print_status "INFO" "Check log: $VM_DIR/logs/$VM_NAME.log"
        sleep 2
        return 1
    fi
    
    sleep 2
    return 0
}

# Function to find next available VNC port
find_available_vnc_port() {
    local start_port=${1:-5900}
    local port=$start_port
    
    # VNC ports must be 5900 or higher
    if [ "$port" -lt 5900 ]; then
        port=5900
    fi
    
    while [ $port -lt 6000 ]; do
        if check_port_available "$port"; then
            echo "$port"
            return 0
        fi
        ((port++))
    done
    
    # If no port found in 5900-5999 range
    echo "5900"
    return 1
}

# Function to find next available noVNC port
find_available_novnc_port() {
    local start_port=${1:-6080}
    local port=$start_port
    
    while [ $port -lt 6200 ]; do
        if check_port_available "$port"; then
            echo "$port"
            return 0
        fi
        ((port++))
    done
    
    # If no port found
    echo "6080"
    return 1
}

# Function to install noVNC and websockify
install_novnc() {
    echo
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║  Installing noVNC & websockify                            ║${RESET}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    # Create directory for noVNC inside vms directory
    local novnc_dir="$VM_DIR/novnc"
    
    # Check if already installed and working
    if [ -d "$novnc_dir" ] && [ -f "$novnc_dir/vnc.html" ]; then
        print_status "SUCCESS" "noVNC already installed at $novnc_dir"
        
        # Verify websockify
        if command -v websockify &> /dev/null || [ -f "$HOME/.local/bin/websockify" ]; then
            print_status "SUCCESS" "websockify is installed"
            echo
            print_status "INFO" "Installation complete!"
            return 0
        fi
    fi
    
    # Install websockify first
    print_status "INFO" "Step 1/2: Installing websockify..."
    
    local websockify_installed=false
    
    # Try pip3 first (preferred method)
    if command -v pip3 &> /dev/null; then
        print_status "INFO" "Trying pip3..."
        local pip_output=$(pip3 install websockify --user 2>&1)
        if echo "$pip_output" | grep -q "Successfully installed\|Requirement already satisfied"; then
            websockify_installed=true
            print_status "SUCCESS" "websockify installed via pip3"
            
            # Add to PATH for current session
            export PATH="$HOME/.local/bin:$PATH"
        else
            print_status "WARN" "pip3 install had issues"
            echo "$pip_output" | tail -n 3
        fi
    fi
    
    # Try pip if pip3 failed
    if [ "$websockify_installed" = false ] && command -v pip &> /dev/null; then
        print_status "INFO" "Trying pip..."
        local pip_output=$(pip install websockify --user 2>&1)
        if echo "$pip_output" | grep -q "Successfully installed\|Requirement already satisfied"; then
            websockify_installed=true
            print_status "SUCCESS" "websockify installed via pip"
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi
    
    # Try apt if pip failed
    if [ "$websockify_installed" = false ] && command -v apt-get &> /dev/null; then
        print_status "INFO" "Trying apt-get..."
        if sudo apt-get install -y websockify 2>&1 | grep -q "Setting up\|already"; then
            websockify_installed=true
            print_status "SUCCESS" "websockify installed via apt"
        fi
    fi
    
    # Try dnf/yum for Fedora/CentOS
    if [ "$websockify_installed" = false ] && command -v dnf &> /dev/null; then
        print_status "INFO" "Trying dnf..."
        if sudo dnf install -y python3-websockify 2>&1 | grep -q "Complete\|already"; then
            websockify_installed=true
            print_status "SUCCESS" "websockify installed via dnf"
        fi
    fi
    
    if [ "$websockify_installed" = false ]; then
        print_status "ERROR" "Could not install websockify automatically"
        print_status "INFO" "Try manually: pip3 install websockify --user"
        print_status "INFO" "Then run: export PATH=\"\$HOME/.local/bin:\$PATH\""
        return 1
    fi
    
    # Verify websockify is accessible
    sleep 1
    if command -v websockify &> /dev/null; then
        print_status "SUCCESS" "websockify is in PATH: $(which websockify)"
    elif [ -f "$HOME/.local/bin/websockify" ]; then
        print_status "SUCCESS" "websockify installed at: $HOME/.local/bin/websockify"
    else
        print_status "WARN" "websockify installed but not found in PATH"
        print_status "INFO" "Add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    # Download noVNC to vms/novnc directory
    print_status "INFO" "Step 2/2: Downloading noVNC to $novnc_dir..."
    
    # Remove old installation if exists
    if [ -d "$novnc_dir" ]; then
        print_status "INFO" "Removing old installation..."
        rm -rf "$novnc_dir"
    fi
    
    mkdir -p "$novnc_dir"
    
    # Try git clone first (best method)
    if command -v git &> /dev/null; then
        print_status "INFO" "Using git clone..."
        if git clone --depth 1 https://github.com/novnc/noVNC.git "$novnc_dir" 2>&1 | grep -q "done\|already"; then
            print_status "SUCCESS" "noVNC cloned successfully"
            
            # Verify installation
            if [ -f "$novnc_dir/vnc.html" ]; then
                echo
                print_status "SUCCESS" "noVNC installation complete!"
                print_status "INFO" "Location: $novnc_dir"
                print_status "INFO" "All VM files in one place: $VM_DIR"
                return 0
            fi
        else
            print_status "WARN" "git clone failed, trying alternative method..."
        fi
    fi
    
    # Fallback: download release tarball
    print_status "INFO" "Downloading noVNC release tarball..."
    local temp_file="/tmp/novnc_$(date +%s).tar.gz"
    
    # Try curl
    if command -v curl &> /dev/null; then
        print_status "INFO" "Using curl..."
        if curl -L -o "$temp_file" "https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz" 2>&1; then
            print_status "SUCCESS" "Downloaded noVNC tarball"
            
            # Extract
            print_status "INFO" "Extracting..."
            if tar -xzf "$temp_file" -C "/tmp" 2>&1; then
                mv "/tmp/noVNC-1.4.0"/* "$novnc_dir/" 2>/dev/null
                rm -f "$temp_file"
                
                # Verify
                if [ -f "$novnc_dir/vnc.html" ]; then
                    print_status "SUCCESS" "noVNC extracted successfully"
                    echo
                    print_status "SUCCESS" "noVNC installation complete!"
                    print_status "INFO" "Location: $novnc_dir"
                    print_status "INFO" "All VM files in one place: $VM_DIR"
                    return 0
                fi
            fi
        fi
    fi
    
    # Try wget as last resort
    if command -v wget &> /dev/null; then
        print_status "INFO" "Using wget..."
        if wget -O "$temp_file" "https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz" 2>&1; then
            print_status "SUCCESS" "Downloaded noVNC tarball"
            
            # Extract
            print_status "INFO" "Extracting..."
            if tar -xzf "$temp_file" -C "/tmp" 2>&1; then
                mv "/tmp/noVNC-1.4.0"/* "$novnc_dir/" 2>/dev/null
                rm -f "$temp_file"
                
                # Verify
                if [ -f "$novnc_dir/vnc.html" ]; then
                    print_status "SUCCESS" "noVNC extracted successfully"
                    echo
                    print_status "SUCCESS" "noVNC installation complete!"
                    print_status "INFO" "Location: $novnc_dir"
                    print_status "INFO" "All VM files in one place: $VM_DIR"
                    return 0
                fi
            fi
        fi
    fi
    
    # If we get here, installation failed
    echo
    print_status "ERROR" "Failed to install noVNC"
    print_status "INFO" "Please check your internet connection"
    print_status "INFO" "Or install manually:"
    echo
    echo "  git clone https://github.com/novnc/noVNC.git $novnc_dir"
    echo "  pip3 install websockify --user"
    echo
    return 1
}

# Function to start noVNC websockify proxy (improved)
start_novnc_proxy() {
    local vm_name=$1
    local vnc_port=$2
    local novnc_port=$3
    
    echo
    print_status "INFO" "Starting noVNC web console for $vm_name..."
    
    # Ensure PATH includes user local bin
    export PATH="$HOME/.local/bin:$PATH"
    
    # Check if websockify is available
    local websockify_cmd=""
    if command -v websockify &> /dev/null; then
        websockify_cmd="websockify"
    elif [ -f "$HOME/.local/bin/websockify" ]; then
        websockify_cmd="$HOME/.local/bin/websockify"
    elif [ -f "/usr/bin/websockify" ]; then
        websockify_cmd="/usr/bin/websockify"
    fi
    
    if [ -z "$websockify_cmd" ]; then
        print_status "WARN" "websockify not found - installing..."
        
        # Try to install websockify
        local install_success=false
        if command -v pip3 &> /dev/null; then
            print_status "INFO" "Installing via pip3..."
            if pip3 install websockify --user 2>&1 | tee /tmp/websockify_install.log | grep -q "Successfully installed\|Requirement already satisfied"; then
                install_success=true
                print_status "SUCCESS" "websockify installed via pip3"
            fi
        fi
        
        if [ "$install_success" = false ] && command -v pip &> /dev/null; then
            print_status "INFO" "Installing via pip..."
            if pip install websockify --user 2>&1 | tee /tmp/websockify_install.log | grep -q "Successfully installed\|Requirement already satisfied"; then
                install_success=true
                print_status "SUCCESS" "websockify installed via pip"
            fi
        fi
        
        if [ "$install_success" = false ]; then
            print_status "ERROR" "Failed to install websockify"
            print_status "INFO" "Try manually: pip3 install websockify --user"
            print_status "INFO" "VNC still available on port $vnc_port with VNC client"
            return 1
        fi
        
        # Update PATH and check again
        export PATH="$HOME/.local/bin:$PATH"
        sleep 2
        
        if command -v websockify &> /dev/null; then
            websockify_cmd="websockify"
        elif [ -f "$HOME/.local/bin/websockify" ]; then
            websockify_cmd="$HOME/.local/bin/websockify"
        else
            print_status "ERROR" "websockify installed but not found in PATH"
            print_status "INFO" "Check: ls -la $HOME/.local/bin/websockify"
            print_status "INFO" "VNC still available on port $vnc_port with VNC client"
            return 1
        fi
    fi
    
    print_status "SUCCESS" "Found websockify: $websockify_cmd"
    
    # Find noVNC directory (prioritize vms/novnc)
    local novnc_dir=""
    for dir in "$VM_DIR/novnc" "$HOME/.novnc" "/usr/share/novnc" "/usr/share/webapps/novnc" "$HOME/noVNC"; do
        if [ -d "$dir" ] && [ -f "$dir/vnc.html" ]; then
            novnc_dir="$dir"
            print_status "SUCCESS" "Found noVNC at: $novnc_dir"
            break
        fi
    done
    
    # Install noVNC if not found
    if [ -z "$novnc_dir" ]; then
        print_status "WARN" "noVNC not found - installing..."
        
        if install_novnc; then
            novnc_dir="$VM_DIR/novnc"
            print_status "SUCCESS" "noVNC installed to: $novnc_dir"
        else
            print_status "ERROR" "noVNC installation failed"
            print_status "INFO" "VNC still available on port $vnc_port with VNC client"
            return 1
        fi
    fi
    
    # Verify noVNC files exist
    if [ ! -f "$novnc_dir/vnc.html" ]; then
        print_status "ERROR" "noVNC files incomplete (vnc.html missing)"
        print_status "INFO" "Remove and reinstall: rm -rf $novnc_dir"
        print_status "INFO" "VNC still available on port $vnc_port with VNC client"
        return 1
    fi
    
    # Check if noVNC proxy already running for this VM
    local pid_file="$VM_DIR/pids/$vm_name-novnc.pid"
    if [ -f "$pid_file" ]; then
        local existing_pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
            print_status "SUCCESS" "noVNC proxy already running (PID: $existing_pid)"
            
            # Display URL
            echo
            echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${GREEN}${BOLD}║  noVNC Web Console - Copy this URL:                                  ║${RESET}"
            echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════════════╝${RESET}"
            echo
            echo -e "  ${CYAN}${BOLD}http://localhost:$novnc_port/vnc.html${RESET}"
            echo
            print_status "INFO" "Alternative: Use VNC client → ${BOLD}localhost:$vnc_port${RESET}"
            echo
            
            return 0
        else
            # Stale PID file
            rm -f "$pid_file"
        fi
    fi
    
    # Check if port is already in use
    if ! check_port_available "$novnc_port"; then
        print_status "ERROR" "noVNC port $novnc_port is already in use"
        print_status "INFO" "Stop other VMs or use different port"
        print_status "INFO" "VNC still available on port $vnc_port with VNC client"
        return 1
    fi
    
    # Create directories
    mkdir -p "$VM_DIR/logs"
    mkdir -p "$VM_DIR/pids"
    mkdir -p "$VM_DIR/web"
    
    # Create VNC control panel HTML
    create_vnc_control_panel "$vm_name" "$novnc_port"
    
    # Start websockify in background (no token auth - handled by login page)
    print_status "INFO" "Starting websockify proxy..."
    print_status "INFO" "Binding to localhost:$novnc_port → localhost:$vnc_port"
    
    if [ -n "$VNC_USERNAME" ] && [ -n "$VNC_PASSWORD" ]; then
        print_status "SUCCESS" "VNC authentication enabled (client-side)"
        print_status "INFO" "Username: $VNC_USERNAME"
    else
        print_status "WARN" "VNC authentication disabled - anyone can access"
    fi
    
    # Start websockify - simple mode without token plugin
    nohup "$websockify_cmd" \
        --web="$VM_DIR/web/$vm_name" \
        --log-file="$VM_DIR/logs/$vm_name-novnc.log" \
        "0.0.0.0:$novnc_port" \
        "localhost:$vnc_port" \
        >> "$VM_DIR/logs/$vm_name-novnc.log" 2>&1 &
    
    local novnc_pid=$!
    
    # Save PID immediately
    echo "$novnc_pid" > "$pid_file"
    
    # Wait for it to start
    print_status "INFO" "Waiting for websockify to start (PID: $novnc_pid)..."
    sleep 3
    
    # Verify it started successfully
    if ! kill -0 $novnc_pid 2>/dev/null; then
        print_status "ERROR" "noVNC proxy failed to start"
        print_status "INFO" "Check log: $VM_DIR/logs/$vm_name-novnc.log"
        
        # Show last few lines of log
        if [ -f "$VM_DIR/logs/$vm_name-novnc.log" ]; then
            echo
            print_status "ERROR" "Error details:"
            tail -n 10 "$VM_DIR/logs/$vm_name-novnc.log" | while read line; do
                echo "  ${RED}$line${RESET}"
            done
            echo
        fi
        
        rm -f "$pid_file"
        print_status "INFO" "VNC still available on port $vnc_port with VNC client"
        return 1
    fi
    
    # Verify port is now listening
    local port_check_attempts=0
    while [ $port_check_attempts -lt 5 ]; do
        if ! check_port_available "$novnc_port"; then
            # Port is in use (good - websockify is listening)
            break
        fi
        sleep 1
        ((port_check_attempts++))
    done
    
    if check_port_available "$novnc_port"; then
        print_status "WARN" "noVNC started but port not listening yet"
        print_status "INFO" "Wait a few seconds and try the URL"
    else
        print_status "SUCCESS" "noVNC proxy is listening on port $novnc_port"
    fi
    
    print_status "SUCCESS" "noVNC proxy started successfully (PID: $novnc_pid)"
    
    # Display connection URLs
    echo
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║  🎮 VM Control & VNC Console Access                                   ║${RESET}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    if [ -n "$VNC_USERNAME" ] && [ -n "$VNC_PASSWORD" ]; then
        echo -e "  ${CYAN}${BOLD}🔒 ULTRA SECURE MODE - Authentication Required${RESET}"
        echo
        echo -e "  ${WHITE}${BOLD}Main Access URL:${RESET}"
        echo -e "  ${GREEN}${BOLD}http://localhost:$novnc_port/${RESET}"
        echo
        echo -e "${YELLOW}${BOLD}  Authentication Credentials:${RESET}"
        echo -e "${YELLOW}     Username: ${BOLD}$VNC_USERNAME${RESET}"
        echo -e "${YELLOW}     Password: ${BOLD}********${RESET} ${DIM}(configured)${RESET}"
        echo
        echo -e "  ${GREEN}✓${RESET} All pages protected (/, /vnc.html, /control.html)"
        echo -e "  ${GREEN}✓${RESET} Auto-redirect to login if not authenticated"
        echo -e "  ${GREEN}✓${RESET} Multi-layer security validation"
        echo -e "  ${GREEN}✓${RESET} Session-based authentication"
    else
        echo -e "  ${RED}${BOLD}⚠ WARNING: NO AUTHENTICATION - ANYONE CAN ACCESS!${RESET}"
        echo
        echo -e "  ${WHITE}${BOLD}Main Access URL:${RESET}"
        echo -e "  ${GREEN}${BOLD}http://localhost:$novnc_port/${RESET}"
        echo
        echo -e "${YELLOW}  Enable authentication:${RESET}"
        echo -e "${YELLOW}     1) Stop this VM${RESET}"
        echo -e "${YELLOW}     2) Main menu → ${BOLD}5) Edit VM configuration${RESET}"
        echo -e "${YELLOW}     3) Select ${BOLD}12) VNC Authentication${RESET}"
    fi
    
    echo
    echo -e "  ${CYAN}${BOLD}Alternative Access:${RESET}"
    echo -e "  ${WHITE}VNC Client: ${BOLD}localhost:$vnc_port${RESET}"
    echo
    print_status "INFO" "Log file: $VM_DIR/logs/$vm_name-novnc.log"
    echo
    print_status "INFO" "Troubleshooting commands:"
    echo -e "  ${YELLOW}•${RESET} Check VM: ${BOLD}pgrep -f vm-$vm_name${RESET}"
    echo -e "  ${YELLOW}•${RESET} Check VNC: ${BOLD}ss -tln | grep $vnc_port${RESET}"
    echo -e "  ${YELLOW}•${RESET} View logs: ${BOLD}tail -f $VM_DIR/logs/$vm_name-novnc.log${RESET}"
    echo
    
    return 0
}

# Function to check noVNC status
check_novnc_status() {
    local vm_name=$1
    
    local pid_file="$VM_DIR/pids/$vm_name-novnc.pid"
    
    if [ ! -f "$pid_file" ]; then
        echo "Not running"
        return 1
    fi
    
    local pid=$(cat "$pid_file" 2>/dev/null)
    if [ -z "$pid" ]; then
        echo "Not running"
        return 1
    fi
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "Running (PID: $pid)"
        return 0
    else
        echo "Stopped (stale PID)"
        rm -f "$pid_file"
        return 1
    fi
}

# Function to stop noVNC proxy
stop_novnc_proxy() {
    local vm_name=$1
    local novnc_pid_file="$VM_DIR/pids/$vm_name-novnc.pid"
    
    if [ -f "$novnc_pid_file" ]; then
        local novnc_pid=$(cat "$novnc_pid_file")
        if kill -0 $novnc_pid 2>/dev/null; then
            kill $novnc_pid 2>/dev/null
            print_status "INFO" "noVNC proxy stopped"
        fi
        rm -f "$novnc_pid_file"
    fi
}

# Function to check if VM is running
is_vm_running() {
    local vm_name=$1
    
    # Try to load config silently
    local config_file="$VM_DIR/$vm_name.conf"
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Load the IMG_FILE from config
    local IMG_FILE=""
    source "$config_file" 2>/dev/null || return 1
    
    if [ -z "$IMG_FILE" ]; then
        return 1
    fi
    
    # Check by process name (works for both foreground and background)
    if pgrep -f "vm-$vm_name" >/dev/null 2>&1; then
        return 0
    fi
    
    # Also check by image file path
    if pgrep -f "$IMG_FILE" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Function to mark VM as installed (detach ISO on next boot)
mark_vm_installed() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    local boot_marker="$VM_DIR/.$vm_name.installed"
    local reboot_marker="$VM_DIR/.$vm_name.rebooted"
    
    echo
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║  Mark VM as Installed                                     ║${RESET}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    print_status "INFO" "VM: $vm_name"
    echo
    
    if [ -f "$reboot_marker" ]; then
        print_status "SUCCESS" "VM is already marked as fully installed"
        print_status "INFO" "VM boots from disk only (ISO detached)"
        echo
        read -p "$(print_status "INPUT" "Reset to ISO boot? (y/N): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -f "$boot_marker" "$reboot_marker"
            print_status "SUCCESS" "Markers removed - VM will boot from ISO on next start"
        else
            print_status "INFO" "No changes made"
        fi
    else
        print_status "WARN" "This will mark the VM installation as complete"
        print_status "INFO" "Next boot will use disk only (ISO detached)"
        echo
        read -p "$(print_status "INPUT" "Mark installation as complete? (y/N): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            touch "$boot_marker"
            touch "$reboot_marker"
            print_status "SUCCESS" "VM marked as fully installed!"
            print_status "INFO" "Next boot will use disk only"
            print_status "INFO" "ISO will be detached automatically"
            
            # If VM is running, suggest restart
            if is_vm_running "$vm_name"; then
                echo
                print_status "WARN" "VM is currently running"
                print_status "INFO" "Stop and restart VM to apply changes"
            fi
        else
            print_status "INFO" "No changes made"
        fi
    fi
    
    echo
    sleep 2
}

# Function to stop a running VM
stop_vm() {
    local vm_name=$1
    local force=${2:-true}  # Default to force=true for reliability
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    # Stop noVNC - try systemd first, then manual
    if sudo systemctl is-active "vm-${vm_name}-novnc.service" &>/dev/null 2>&1; then
        print_status "INFO" "Stopping noVNC systemd service..."
        sudo systemctl stop "vm-${vm_name}-novnc.service" 2>/dev/null
    fi
    
    # Also stop manual noVNC proxy if running
    stop_novnc_proxy "$vm_name"
    
    # Check if IMG_FILE is set
    if [ -z "$IMG_FILE" ]; then
        print_status "ERROR" "IMG_FILE not found in configuration"
        sleep 2
        return 1
    fi
    
    if ! is_vm_running "$vm_name"; then
        print_status "INFO" "VM '$vm_name' is not running"
        sleep 2
        return 0
    fi
    
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Stopping VM: %-44s║${RESET}" "$vm_name"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    # Find ALL QEMU processes related to this VM using multiple methods
    local qemu_pids=()
    
    # Method 1: By process name (most reliable)
    while IFS= read -r pid; do
        [ -n "$pid" ] && qemu_pids+=("$pid")
    done < <(pgrep -f "vm-$vm_name" 2>/dev/null || true)
    
    # Method 2: By image file
    if [ ${#qemu_pids[@]} -eq 0 ] && [ -n "$IMG_FILE" ]; then
        while IFS= read -r pid; do
            [ -n "$pid" ] && qemu_pids+=("$pid")
        done < <(pgrep -f "$IMG_FILE" 2>/dev/null || true)
    fi
    
    # Method 3: By VM name in command line
    if [ ${#qemu_pids[@]} -eq 0 ]; then
        while IFS= read -r pid; do
            [ -n "$pid" ] && qemu_pids+=("$pid")
        done < <(ps aux 2>/dev/null | grep "[q]emu-system-x86_64" | grep "$vm_name" | awk '{print $2}' || true)
    fi
    
    # Method 4: Check PID file
    local pid_file="$VM_DIR/pids/$vm_name.pid"
    if [ ${#qemu_pids[@]} -eq 0 ] && [ -f "$pid_file" ]; then
        local file_pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$file_pid" ] && kill -0 "$file_pid" 2>/dev/null; then
            qemu_pids+=("$file_pid")
        fi
    fi
    
    if [ ${#qemu_pids[@]} -eq 0 ]; then
        print_status "WARN" "Could not find VM process"
        print_status "INFO" "VM may have already stopped"
        
        # Clean up PID file if exists
        [ -f "$pid_file" ] && rm -f "$pid_file"
        
        echo
        sleep 2
        return 0
    fi
    
    # Remove duplicates and sort
    qemu_pids=($(printf '%s\n' "${qemu_pids[@]}" | sort -u))
    
    print_status "INFO" "Found ${#qemu_pids[@]} process(es): ${qemu_pids[*]}"
    echo
    
    # Try to kill each process with escalating signals
    local all_stopped=true
    local stopped_count=0
    
    for pid in "${qemu_pids[@]}"; do
        echo -e "${CYAN}${BOLD}[→]${RESET} ${CYAN}Stopping PID $pid...${RESET}"
        
        # Try SIGTERM first (graceful)
        if kill -TERM "$pid" 2>/dev/null; then
            echo -ne "  ${DIM}Waiting for graceful shutdown (3s)...${RESET} "
            
            local waited=0
            while [ $waited -lt 3 ]; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    echo -e "${GREEN}✓ Stopped gracefully${RESET}"
                    ((stopped_count++))
                    continue 2
                fi
                sleep 1
                ((waited++))
            done
            
            echo -e "${YELLOW}⚠ Still running${RESET}"
        fi
        
        # Try SIGKILL (force)
        echo -ne "  ${DIM}Force killing...${RESET} "
        if kill -9 "$pid" 2>/dev/null; then
            sleep 0.5
            if ! kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}✓ Force killed${RESET}"
                ((stopped_count++))
            else
                echo -e "${RED}✗ Failed${RESET}"
                all_stopped=false
            fi
        else
            echo -e "${RED}✗ Permission denied${RESET}"
            all_stopped=false
        fi
    done
    
    echo
    
    # Clean up PID file
    [ -f "$pid_file" ] && rm -f "$pid_file"
    
    # Final verification
    sleep 1
    local still_running=0
    for pid in "${qemu_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            ((still_running++))
        fi
    done
    
    if [ $still_running -eq 0 ]; then
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}${BOLD}║     ✓ VM Stopped Successfully                             ║${RESET}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        print_status "SUCCESS" "Stopped $stopped_count process(es)"
        sleep 2
        return 0
    else
        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}${BOLD}║     ✗ Failed to Stop VM                                   ║${RESET}"
        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        print_status "ERROR" "$still_running process(es) still running"
        print_status "INFO" "You may need to run with elevated privileges:"
        echo
        echo -e "${DIM}  sudo kill -9 ${qemu_pids[*]}${RESET}"
        echo
        sleep 3
        return 1
    fi
}

# Function to delete a VM
delete_vm() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BOLD}║                    ⚠ WARNING ⚠                           ║${RESET}"
    echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    print_status "WARN" "This will permanently delete VM '$vm_name' and ALL its data!"
    echo
    echo -e "  ${DIM}VM Name:${RESET}    $vm_name"
    echo -e "  ${DIM}Image:${RESET}      $IMG_FILE"
    echo -e "  ${DIM}Seed:${RESET}       $SEED_FILE"
    echo -e "  ${DIM}Config:${RESET}     $VM_DIR/$vm_name.conf"
    echo
    
    read -p "$(print_status "INPUT" "Type '${BOLD}yes${RESET}${CYAN}' to confirm deletion: ")" confirm
    
    if [[ "$confirm" == "yes" ]]; then
        # Stop VM if running
        if is_vm_running "$vm_name" 2>/dev/null; then
            print_status "INFO" "Stopping running VM..."
            stop_vm "$vm_name"
        fi
        
        # Delete files
        print_status "INFO" "Deleting VM files..."
        local deleted=0
        
        if [ -f "$IMG_FILE" ]; then
            rm -f "$IMG_FILE" && ((deleted++)) && print_status "SUCCESS" "Deleted image file"
        fi
        
        if [ -f "$SEED_FILE" ]; then
            rm -f "$SEED_FILE" && ((deleted++)) && print_status "SUCCESS" "Deleted seed file"
        fi
        
        if [ -f "$VM_DIR/$vm_name.conf" ]; then
            rm -f "$VM_DIR/$vm_name.conf" && ((deleted++)) && print_status "SUCCESS" "Deleted config file"
        fi
        
        # Clean up PID file
        local pid_file="$VM_DIR/pids/$vm_name.pid"
        if [ -f "$pid_file" ]; then
            rm -f "$pid_file" && print_status "SUCCESS" "Deleted PID file"
        fi
        
        # Clean up log file
        local log_file="$VM_DIR/logs/$vm_name.log"
        if [ -f "$log_file" ]; then
            rm -f "$log_file" && print_status "SUCCESS" "Deleted log file"
        fi
        
        echo
        if [ $deleted -gt 0 ]; then
            print_status "SUCCESS" "VM '$vm_name' has been deleted ($deleted files removed)"
        else
            print_status "WARN" "No files were found to delete"
        fi
    else
        print_status "INFO" "Deletion cancelled"
    fi
    sleep 1
}

# Function to show VM info
show_vm_info() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    local status="${RED}Stopped${RESET}"
    local status_icon="${RED}●${RESET}"
    if is_vm_running "$vm_name"; then
        status="${GREEN}Running${RESET}"
        status_icon="${GREEN}●${RESET}"
    fi
    
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     VM Information: ${WHITE}$vm_name${CYAN}$(printf '%*s' $((37 - ${#vm_name})) '')║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "  ${CYAN}Status:${RESET}         $status_icon $status"
    echo -e "  ${CYAN}OS:${RESET}             ${BOLD}$OS_TYPE${RESET}"
    echo -e "  ${CYAN}Hostname:${RESET}       ${BOLD}$HOSTNAME${RESET}"
    echo -e "  ${CYAN}Username:${RESET}       ${BOLD}$USERNAME${RESET}"
    echo -e "  ${CYAN}Password:${RESET}       ${BOLD}$PASSWORD${RESET}"
    echo -e "  ${CYAN}SSH Port:${RESET}       ${BOLD}$SSH_PORT${RESET}"
    echo -e "  ${CYAN}Memory:${RESET}         ${BOLD}$MEMORY MB${RESET}"
    echo -e "  ${CYAN}CPUs:${RESET}           ${BOLD}$CPUS${RESET}"
    echo -e "  ${CYAN}CPU Model:${RESET}      ${BOLD}$CPU_MODEL${RESET}"
    
    # Show custom CPU string if available
    if [ -n "$CUSTOM_CPU_STRING" ] && [[ ! "$CPU_MODEL" =~ ^(Host CPU|QEMU Default).*$ ]]; then
        echo -e "  ${CYAN}CPU String:${RESET}     ${DIM}$CUSTOM_CPU_STRING${RESET}"
    fi
    
    echo -e "  ${CYAN}Disk Size:${RESET}      ${BOLD}$DISK_SIZE${RESET}"
    echo -e "  ${CYAN}GUI Mode:${RESET}       ${BOLD}$GUI_MODE${RESET}"
    echo -e "  ${CYAN}Port Forwards:${RESET}  ${BOLD}${PORT_FORWARDS:-None}${RESET}"
    echo -e "  ${CYAN}Autostart:${RESET}      ${BOLD}${AUTOSTART:-false}${RESET}"
    echo -e "  ${CYAN}Created:${RESET}        ${BOLD}$CREATED${RESET}"
    
    # Show installation status for ISO-based VMs
    local boot_marker="$VM_DIR/.$vm_name.installed"
    local reboot_marker="$VM_DIR/.$vm_name.rebooted"
    
    if [[ "$OS_TYPE" == "proxmox" ]] || [[ "$IMG_FILE" == *".iso"* ]] || [[ "$IMG_FILE" == *".iso_cache"* ]]; then
        echo
        echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${BLUE}║     Installation Status                                    ║${RESET}"
        echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        
        if [ -f "$reboot_marker" ]; then
            echo -e "  ${GREEN}${BOLD}✓ Installation Complete${RESET}"
            echo -e "  ${GREEN}Boot Mode:${RESET} Disk only (ISO detached)"
        elif [ -f "$boot_marker" ]; then
            echo -e "  ${YELLOW}${BOLD}⚙ Installation In Progress${RESET}"
            echo -e "  ${YELLOW}Boot Mode:${RESET} Disk with ISO fallback"
            echo -e "  ${DIM}After installation completes and VM reboots, stop and start VM${RESET}"
            echo -e "  ${DIM}Or use option 'm' to manually mark as installed${RESET}"
        else
            echo -e "  ${BLUE}${BOLD}◯ First Boot${RESET}"
            echo -e "  ${BLUE}Boot Mode:${RESET} ISO installer"
            echo -e "  ${DIM}VM will boot from ISO to begin installation${RESET}"
        fi
    fi
    
    echo
    echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${MAGENTA}║     SMBIOS Branding                                        ║${RESET}"
    echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "  ${MAGENTA}Manufacturer:${RESET}   ${BOLD}${SMBIOS_MANUFACTURER:-VM}${RESET}"
    echo -e "  ${MAGENTA}Product:${RESET}        ${BOLD}${SMBIOS_PRODUCT:-VM}${RESET}"
    echo -e "  ${MAGENTA}Version:${RESET}        ${BOLD}${SMBIOS_VERSION:-1.0}${RESET}"
    echo
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║     SSH Connection Commands                                ║${RESET}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "  ${GREEN}${BOLD}Root Login:${RESET}"
    echo -e "    ${WHITE}ssh root@localhost -p $SSH_PORT${RESET}"
    echo -e "    ${DIM}Password: $PASSWORD${RESET}"
    echo
    echo -e "  ${GREEN}${BOLD}User Login:${RESET}"
    echo -e "    ${WHITE}ssh $USERNAME@localhost -p $SSH_PORT${RESET}"
    echo -e "    ${DIM}Password: $PASSWORD${RESET}"
    echo
    echo -e "  ${YELLOW}${BOLD}Note:${RESET} ${DIM}Root login is enabled with password authentication${RESET}"
    echo -e "  ${YELLOW}${BOLD}Note:${RESET} ${DIM}Wait 1-2 minutes after VM start for SSH to be ready${RESET}"
    echo
    
    # Show VNC info if configured
    if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
        echo -e "${BOLD}${YELLOW}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${YELLOW}║     VNC/noVNC Access                                       ║${RESET}"
        echo -e "${BOLD}${YELLOW}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        echo -e "  ${YELLOW}${BOLD}Web Console:${RESET}"
        echo -e "    ${WHITE}http://localhost:$NOVNC_PORT/vnc.html${RESET}"
        echo
        echo -e "  ${YELLOW}${BOLD}VNC Client:${RESET}"
        echo -e "    ${WHITE}localhost:$VNC_PORT${RESET}"
        echo
        
        if [ -n "$VNC_USERNAME" ] && [ -n "$VNC_PASSWORD" ]; then
            echo -e "  ${GREEN}${BOLD}🔒 Authentication:${RESET} ${GREEN}Enabled${RESET}"
            echo -e "    ${DIM}Username: ${BOLD}$VNC_USERNAME${RESET}"
            echo -e "    ${DIM}Password: ${BOLD}********${RESET} ${DIM}(configured)${RESET}"
        else
            echo -e "  ${RED}${BOLD}⚠ Authentication:${RESET} ${RED}Disabled${RESET}"
            echo -e "    ${DIM}Anyone can access without password${RESET}"
        fi
        echo
    fi
    
    echo -e "${DIM}Files:${RESET}"
    echo -e "  ${DIM}Image: $IMG_FILE${RESET}"
    echo -e "  ${DIM}Seed:  $SEED_FILE${RESET}"
    echo -e "  ${DIM}Log:   $VM_DIR/logs/$vm_name.log${RESET}"
    echo
    
    read -p "$(print_status "INPUT" "Press Enter to continue...")"
}

# Function to edit VM configuration
edit_vm_config() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    while true; do
        echo
        echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║     Edit VM: ${WHITE}$vm_name${CYAN}$(printf '%*s' $((20 - ${#vm_name})) '')║${RESET}"
        echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════╝${RESET}"
        echo
        echo "  1) Hostname       (current: $HOSTNAME)"
        echo "  2) Username       (current: $USERNAME)"
        echo "  3) Password       (current: ****)"
        echo "  4) SSH Port       (current: $SSH_PORT)"
        echo "  5) CPU Model      (current: $CPU_MODEL)"
        echo "  6) GUI Mode       (current: $GUI_MODE)"
        echo "  7) Port Forwards  (current: ${PORT_FORWARDS:-None})"
        echo "  8) Memory         (current: $MEMORY MB)"
        echo "  9) CPU Count      (current: $CPUS)"
        echo " 10) Disk Size      (current: $DISK_SIZE)"
        echo " 11) SMBIOS Branding"
        if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
            local vnc_auth_status="${RED}Disabled${RESET}"
            if [ -n "$VNC_USERNAME" ] && [ -n "$VNC_PASSWORD" ]; then
                vnc_auth_status="${GREEN}Enabled (User: $VNC_USERNAME)${RESET}"
            fi
            echo -e " 12) VNC Authentication (current: $vnc_auth_status)"
        fi
        echo "  0) Back to main menu"
        echo
        
        read -p "$(print_status "INPUT" "Select option: ")" edit_choice
        
        local needs_seed_update=false
        
        case $edit_choice in
            1)
                while true; do
                    read -p "$(print_status "INPUT" "New hostname [${DIM}$HOSTNAME${RESET}]: ")" new_hostname
                    new_hostname="${new_hostname:-$HOSTNAME}"
                    if validate_input "name" "$new_hostname"; then
                        HOSTNAME="$new_hostname"
                        needs_seed_update=true
                        break
                    fi
                done
                ;;
            2)
                while true; do
                    read -p "$(print_status "INPUT" "New username [${DIM}$USERNAME${RESET}]: ")" new_username
                    new_username="${new_username:-$USERNAME}"
                    if validate_input "username" "$new_username"; then
                        USERNAME="$new_username"
                        needs_seed_update=true
                        break
                    fi
                done
                ;;
            3)
                while true; do
                    read -s -p "$(print_status "INPUT" "New password: ")" new_password
                    echo
                    if [ -n "$new_password" ]; then
                        PASSWORD="$new_password"
                        needs_seed_update=true
                        break
                    else
                        print_status "ERROR" "Password cannot be empty"
                    fi
                done
                ;;
            4)
                while true; do
                    read -p "$(print_status "INPUT" "New SSH port [${DIM}$SSH_PORT${RESET}]: ")" new_ssh_port
                    new_ssh_port="${new_ssh_port:-$SSH_PORT}"
                    if validate_input "port" "$new_ssh_port"; then
                        if [ "$new_ssh_port" != "$SSH_PORT" ] && ! check_port_available "$new_ssh_port"; then
                            print_status "ERROR" "Port $new_ssh_port is already in use"
                        else
                            SSH_PORT="$new_ssh_port"
                            break
                        fi
                    fi
                done
                ;;
            5)
                select_cpu_model
                ;;
            6)
                while true; do
                    read -p "$(print_status "INPUT" "Enable GUI? (y/n) [${DIM}$GUI_MODE${RESET}]: ")" gui_input
                    if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
                        GUI_MODE=true
                        break
                    elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                        GUI_MODE=false
                        break
                    elif [ -z "$gui_input" ]; then
                        break
                    else
                        print_status "ERROR" "Please answer y or n"
                    fi
                done
                ;;
            7)
                read -p "$(print_status "INPUT" "Port forwards [${DIM}${PORT_FORWARDS:-None}${RESET}]: ")" new_port_forwards
                PORT_FORWARDS="${new_port_forwards:-$PORT_FORWARDS}"
                ;;
            8)
                while true; do
                    read -p "$(print_status "INPUT" "New memory in MB [${DIM}$MEMORY${RESET}]: ")" new_memory
                    new_memory="${new_memory:-$MEMORY}"
                    if validate_input "number" "$new_memory"; then
                        MEMORY="$new_memory"
                        break
                    fi
                done
                ;;
            9)
                while true; do
                    read -p "$(print_status "INPUT" "New CPU count [${DIM}$CPUS${RESET}]: ")" new_cpus
                    new_cpus="${new_cpus:-$CPUS}"
                    if validate_input "number" "$new_cpus"; then
                        CPUS="$new_cpus"
                        break
                    fi
                done
                ;;
            10)
                while true; do
                    read -p "$(print_status "INPUT" "New disk size [${DIM}$DISK_SIZE${RESET}]: ")" new_disk_size
                    new_disk_size="${new_disk_size:-$DISK_SIZE}"
                    new_disk_size=$(normalize_disk_size "$new_disk_size")
                    if validate_input "size" "$new_disk_size"; then
                        print_status "INFO" "Resizing disk..."
                        if qemu-img resize "$IMG_FILE" "$new_disk_size" &>/dev/null; then
                            DISK_SIZE="$new_disk_size"
                            print_status "SUCCESS" "Disk resized"
                        else
                            print_status "ERROR" "Failed to resize disk"
                        fi
                        break
                    fi
                done
                ;;
            11)
                echo
                echo -e "${BOLD}${MAGENTA}╔═══════════════════════════════════════╗${RESET}"
                echo -e "${BOLD}${MAGENTA}║     SMBIOS Branding Configuration     ║${RESET}"
                echo -e "${BOLD}${MAGENTA}╚═══════════════════════════════════════╝${RESET}"
                echo
                echo -e "  ${DIM}Current Settings:${RESET}"
                echo -e "  Manufacturer: ${BOLD}${SMBIOS_MANUFACTURER:-VM}${RESET}"
                echo -e "  Product:      ${BOLD}${SMBIOS_PRODUCT:-VM}${RESET}"
                echo -e "  Version:      ${BOLD}${SMBIOS_VERSION:-1.0}${RESET}"
                echo
                
                read -p "$(print_status "INPUT" "Manufacturer [${DIM}${SMBIOS_MANUFACTURER:-VM}${RESET}]: ")" new_manufacturer
                SMBIOS_MANUFACTURER="${new_manufacturer:-${SMBIOS_MANUFACTURER:-VM}}"
                
                read -p "$(print_status "INPUT" "Product Name [${DIM}${SMBIOS_PRODUCT:-VM}${RESET}]: ")" new_product
                SMBIOS_PRODUCT="${new_product:-${SMBIOS_PRODUCT:-VM}}"
                
                read -p "$(print_status "INPUT" "Version [${DIM}${SMBIOS_VERSION:-1.0}${RESET}]: ")" new_version
                SMBIOS_VERSION="${new_version:-${SMBIOS_VERSION:-1.0}}"
                
                print_status "SUCCESS" "SMBIOS branding updated"
                ;;
            12)
                # Only allow if VNC is configured
                if [ -z "$VNC_PORT" ] || [ -z "$NOVNC_PORT" ]; then
                    print_status "ERROR" "VNC is not configured for this VM"
                    sleep 2
                    continue
                fi
                
                echo
                echo -e "${BOLD}${YELLOW}╔═══════════════════════════════════════╗${RESET}"
                echo -e "${BOLD}${YELLOW}║     VNC Authentication Setup          ║${RESET}"
                echo -e "${BOLD}${YELLOW}╚═══════════════════════════════════════╝${RESET}"
                echo
                
                local current_status="${RED}Disabled${RESET}"
                if [ -n "$VNC_USERNAME" ] && [ -n "$VNC_PASSWORD" ]; then
                    current_status="${GREEN}Enabled${RESET}"
                    echo -e "  ${DIM}Current Status:${RESET} $current_status"
                    echo -e "  ${DIM}Current User:${RESET}   ${BOLD}$VNC_USERNAME${RESET}"
                else
                    echo -e "  ${DIM}Current Status:${RESET} $current_status"
                fi
                echo
                
                read -p "$(print_status "INPUT" "Enable VNC password protection? (y/n): ")" enable_vnc_auth
                
                if [[ "$enable_vnc_auth" =~ ^[Yy]$ ]]; then
                    while true; do
                        read -p "$(print_status "INPUT" "VNC Username [${DIM}${VNC_USERNAME:-admin}${RESET}]: ")" new_vnc_user
                        new_vnc_user="${new_vnc_user:-${VNC_USERNAME:-admin}}"
                        if validate_input "username" "$new_vnc_user"; then
                            VNC_USERNAME="$new_vnc_user"
                            break
                        fi
                    done
                    
                    while true; do
                        read -s -p "$(print_status "INPUT" "VNC Password (min 6 chars): ")" new_vnc_pass
                        echo
                        if [ ${#new_vnc_pass} -ge 6 ]; then
                            read -s -p "$(print_status "INPUT" "Confirm VNC Password: ")" vnc_pass_confirm
                            echo
                            if [ "$new_vnc_pass" = "$vnc_pass_confirm" ]; then
                                VNC_PASSWORD="$new_vnc_pass"
                                break
                            else
                                print_status "ERROR" "Passwords do not match"
                            fi
                        else
                            print_status "ERROR" "Password must be at least 6 characters"
                        fi
                    done
                    
                    print_status "SUCCESS" "VNC authentication enabled"
                    print_status "WARN" "Restart VM for changes to take effect"
                else
                    VNC_USERNAME=""
                    VNC_PASSWORD=""
                    print_status "INFO" "VNC authentication disabled"
                    print_status "WARN" "VNC will be accessible without password"
                    print_status "WARN" "Restart VM for changes to take effect"
                fi
                ;;
            0)
                return 0
                ;;
            *)
                print_status "ERROR" "Invalid selection"
                sleep 1
                continue
                ;;
        esac
        
        if [ "$needs_seed_update" = true ]; then
            print_status "INFO" "Updating cloud-init configuration..."
            setup_vm_image
        fi
        
        save_vm_config
        print_status "SUCCESS" "Configuration updated"
        
        read -p "$(print_status "INPUT" "Continue editing? (y/N): ")" continue_editing
        if [[ ! "$continue_editing" =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

# Function to show VM performance
show_vm_performance() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Performance: ${WHITE}$vm_name${CYAN}$(printf '%*s' $((33 - ${#vm_name})) '')║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    if is_vm_running "$vm_name"; then
        # Get the base filename for matching
        local img_basename=$(basename "$IMG_FILE" 2>/dev/null)
        
        if [ -n "$img_basename" ]; then
            local qemu_pid=$(pgrep -f "qemu-system-x86_64.*$img_basename" 2>/dev/null | head -1)
            
            if [[ -n "$qemu_pid" ]]; then
                echo -e "${BOLD}QEMU Process:${RESET}"
                if command -v ps &> /dev/null; then
                    ps -p "$qemu_pid" -o pid,%cpu,%mem,rss,vsz,cmd --no-headers 2>/dev/null | \
                        awk '{printf "  PID: %s  CPU: %s%%  MEM: %s%%  RSS: %s KB  VSZ: %s KB\n", $1, $2, $3, $4, $5}' || \
                        echo "  Process info unavailable"
                fi
                echo
                
                echo -e "${BOLD}System Memory:${RESET}"
                if command -v free &> /dev/null; then
                    free -h 2>/dev/null | awk 'NR==1 {print "  " $0} NR==2 {print "  " $0}' || echo "  Memory info unavailable"
                else
                    echo "  Memory info unavailable"
                fi
                echo
                
                echo -e "${BOLD}Disk Usage:${RESET}"
                if [ -f "$IMG_FILE" ]; then
                    local disk_size=$(du -h "$IMG_FILE" 2>/dev/null | cut -f1)
                    echo "  VM Image: $disk_size ($IMG_FILE)"
                fi
            else
                print_status "ERROR" "Could not find QEMU process"
            fi
        else
            print_status "ERROR" "Invalid IMG_FILE path"
        fi
    else
        print_status "INFO" "VM is not running"
        echo
        echo -e "${BOLD}Configuration:${RESET}"
        echo "  Memory: $MEMORY MB"
        echo "  CPUs: $CPUS"
        echo "  CPU Model: $CPU_MODEL"
        echo "  Disk: $DISK_SIZE"
        if [ -f "$IMG_FILE" ]; then
            local disk_size=$(du -h "$IMG_FILE" 2>/dev/null | cut -f1)
            echo "  Actual disk usage: $disk_size"
        fi
    fi
    
    echo
    read -p "$(print_status "INPUT" "Press Enter to continue...")"
}

# Function to clone a VM
clone_vm() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    print_status "INFO" "Cloning VM: $vm_name"
    echo
    
    # Get new VM name
    local new_vm_name
    while true; do
        read -p "$(print_status "INPUT" "New VM name: ")" new_vm_name
        if [ -z "$new_vm_name" ]; then
            print_status "ERROR" "VM name cannot be empty"
        elif validate_input "name" "$new_vm_name"; then
            if [[ -f "$VM_DIR/$new_vm_name.conf" ]]; then
                print_status "ERROR" "VM '$new_vm_name' already exists"
            else
                break
            fi
        fi
    done
    
    # Get new SSH port
    local new_ssh_port
    while true; do
        read -p "$(print_status "INPUT" "New SSH port [${DIM}$((SSH_PORT + 1))${RESET}]: ")" new_ssh_port
        new_ssh_port="${new_ssh_port:-$((SSH_PORT + 1))}"
        if validate_input "port" "$new_ssh_port"; then
            if ! check_port_available "$new_ssh_port"; then
                print_status "ERROR" "Port $new_ssh_port is already in use"
            else
                break
            fi
        fi
    done
    
    # Clone files
    print_status "INFO" "Copying VM image (this may take a while)..."
    local new_img_file="$VM_DIR/$new_vm_name.img"
    local new_seed_file="$VM_DIR/$new_vm_name-seed.iso"
    
    # Check if source files exist
    if [ ! -f "$IMG_FILE" ]; then
        print_status "ERROR" "Source image file not found: $IMG_FILE"
        sleep 2
        return 1
    fi
    
    if cp "$IMG_FILE" "$new_img_file" 2>/dev/null; then
        print_status "SUCCESS" "Image copied"
    else
        print_status "ERROR" "Failed to copy image"
        return 1
    fi
    
    if [ -f "$SEED_FILE" ]; then
        if cp "$SEED_FILE" "$new_seed_file" 2>/dev/null; then
            print_status "SUCCESS" "Seed copied"
        else
            print_status "WARN" "Failed to copy seed, creating new one..."
            rm -f "$new_img_file"
            return 1
        fi
    else
        print_status "WARN" "Source seed not found, will create new one"
    fi
    
    # Save new configuration
    VM_NAME="$new_vm_name"
    SSH_PORT="$new_ssh_port"
    IMG_FILE="$new_img_file"
    SEED_FILE="$new_seed_file"
    HOSTNAME="$new_vm_name"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"
    
    save_vm_config
    
    print_status "SUCCESS" "VM cloned successfully as '$new_vm_name'"
    sleep 1
}

# Function to open VM console
open_vm_console() {
    local vm_name=$1
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     VM Console Access                                     ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    # Check if VM is running
    if ! is_vm_running "$vm_name"; then
        print_status "ERROR" "VM '$vm_name' is not running"
        print_status "INFO" "Start the VM first using option 2"
        sleep 2
        return 1
    fi
    
    # Get monitor socket path
    local monitor_socket="$VM_DIR/monitors/$vm_name.sock"
    
    if [ ! -S "$monitor_socket" ]; then
        print_status "ERROR" "Monitor socket not found: $monitor_socket"
        print_status "INFO" "VM may need to be restarted to enable console access"
        sleep 2
        return 1
    fi
    
    print_status "INFO" "Opening console for VM: $vm_name"
    echo
    echo -e "${BOLD}Console Access Methods:${RESET}"
    echo "  1) SSH (Recommended)"
    echo "  2) QEMU Monitor"
    echo "  3) View Logs"
    echo "  0) Cancel"
    echo
    
    read -p "$(print_status "INPUT" "Select method: ")" method
    
    case $method in
        1)
            print_status "INFO" "Connecting via SSH..."
            echo
            echo -e "${BOLD}${GREEN}SSH Connection Details:${RESET}"
            echo -e "  ${CYAN}Command:${RESET} ${BOLD}ssh -p $SSH_PORT $USERNAME@localhost${RESET}"
            echo -e "  ${CYAN}Password:${RESET} ${BOLD}$PASSWORD${RESET}"
            echo
            read -p "$(print_status "INPUT" "Press Enter to connect (or Ctrl+C to cancel)...")"
            
            # Try to connect via SSH
            ssh -p "$SSH_PORT" "$USERNAME@localhost"
            ;;
        2)
            print_status "INFO" "Opening QEMU Monitor..."
            echo
            echo -e "${DIM}Commands: info status, info network, quit${RESET}"
            echo
            sleep 1
            
            # Connect to monitor socket
            if command -v socat &> /dev/null; then
                socat - "UNIX-CONNECT:$monitor_socket"
            elif command -v nc &> /dev/null; then
                nc -U "$monitor_socket"
            else
                print_status "ERROR" "Neither socat nor nc found"
                print_status "INFO" "Install: sudo apt install socat"
                sleep 2
            fi
            ;;
        3)
            print_status "INFO" "Viewing VM logs..."
            echo
            local log_file="$VM_DIR/logs/$vm_name.log"
            if [ -f "$log_file" ]; then
                echo -e "${DIM}Press Ctrl+C to exit${RESET}"
                sleep 1
                tail -f "$log_file"
            else
                print_status "ERROR" "Log file not found: $log_file"
                sleep 2
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_status "ERROR" "Invalid selection"
            sleep 1
            ;;
    esac
}

# Function to start VM with console option
start_vm_with_console() {
    local vm_name=$1
    local open_console=${2:-false}
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    print_status "INFO" "Starting VM: ${BOLD}$vm_name${RESET}"
    echo
    
    # Verify files exist
    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "ERROR" "VM image not found: $IMG_FILE"
        echo
        print_status "INFO" "The VM may be corrupted. Try recreating it."
        sleep 2
        return 1
    fi
    
    if [[ ! -f "$SEED_FILE" ]]; then
        print_status "WARN" "Seed file missing: $SEED_FILE"
        print_status "INFO" "Recreating seed file..."
        if ! setup_vm_image; then
            print_status "ERROR" "Failed to recreate seed file"
            sleep 2
            return 1
        fi
    fi
    
    # Check port availability
    if ! check_port_available "$SSH_PORT"; then
        print_status "ERROR" "Port $SSH_PORT is already in use!"
        print_status "INFO" "Use option 5 (Edit VM) to change the SSH port"
        sleep 2
        return 1
    fi
    
    # Display connection info
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║     Connection Information            ║${RESET}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════╝${RESET}"
    echo -e "  ${CYAN}SSH:${RESET}      ${BOLD}ssh -p $SSH_PORT $USERNAME@localhost${RESET}"
    echo -e "  ${CYAN}Username:${RESET} ${BOLD}$USERNAME${RESET}"
    echo -e "  ${CYAN}Password:${RESET} ${BOLD}$PASSWORD${RESET}"
    echo -e "  ${CYAN}CPU Model:${RESET} ${BOLD}$CPU_MODEL${RESET}"
    echo
    
    # Build QEMU command
    local qemu_cmd=(qemu-system-x86_64)
    
    # Detect available machine type
    local machine_type="pc"
    if command -v qemu-system-x86_64 &> /dev/null; then
        local available_machine=$(qemu-system-x86_64 -machine help 2>/dev/null | grep -E "^pc-i440fx" | head -1 | awk '{print $1}')
        if [ -n "$available_machine" ]; then
            machine_type="$available_machine"
        fi
    fi
    
    qemu_cmd+=(-machine "$machine_type")
    qemu_cmd+=(-name "VM-$VM_NAME,process=vm-$VM_NAME")
    
    print_status "INFO" "Machine type: $machine_type"
    
    # KVM acceleration and CPU model
    if [ "$KVM_AVAILABLE" = true ]; then
        qemu_cmd+=(-enable-kvm)
        print_status "SUCCESS" "Using KVM hardware acceleration"
        
        local cpu_string="${CPU_MODELS[$CPU_MODEL]}"
        if [ -z "$cpu_string" ] && [ -n "$CUSTOM_CPU_STRING" ]; then
            cpu_string="$CUSTOM_CPU_STRING"
        fi
        if [ -z "$cpu_string" ]; then
            cpu_string="host"
        fi
        
        qemu_cmd+=(-cpu "$cpu_string")
        print_status "INFO" "CPU Model: $CPU_MODEL"
    else
        qemu_cmd+=(-cpu qemu64)
        print_status "WARN" "KVM not available, using software emulation"
    fi
    
    # Basic configuration
    qemu_cmd+=(
        -m "$MEMORY"
        -smp "$CPUS"
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -boot order=c
        -device virtio-net-pci,netdev=n0
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
    )
    
    # SMBIOS customization - Use configured branding
    qemu_cmd+=(
        -smbios "type=0,vendor=${SMBIOS_MANUFACTURER:-VM},version=${SMBIOS_VERSION:-1.0},date=$(date +%m/%d/%Y)"
        -smbios "type=1,manufacturer=${SMBIOS_MANUFACTURER:-VM},product=${SMBIOS_PRODUCT:-VM},version=${SMBIOS_VERSION:-1.0},serial=$VM_NAME-$(date +%s),uuid=$(uuidgen 2>/dev/null || echo "00000000-0000-0000-0000-$(printf '%012d' $$)"),family=${SMBIOS_MANUFACTURER:-VM} Virtual Machine"
        -smbios "type=2,manufacturer=${SMBIOS_MANUFACTURER:-VM},product=${SMBIOS_PRODUCT:-VM} Motherboard,version=${SMBIOS_VERSION:-1.0},serial=MB-$VM_NAME"
        -smbios "type=3,manufacturer=${SMBIOS_MANUFACTURER:-VM},version=${SMBIOS_VERSION:-1.0}"
    )

    # Port forwards
    if [[ -n "$PORT_FORWARDS" ]]; then
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        local net_id=1
        for forward in "${forwards[@]}"; do
            forward=$(echo "$forward" | xargs)
            if [[ "$forward" =~ ^([0-9]+):([0-9]+)$ ]]; then
                local host_port="${BASH_REMATCH[1]}"
                local guest_port="${BASH_REMATCH[2]}"
                if check_port_available "$host_port"; then
                    qemu_cmd+=(-netdev "user,id=n$net_id,hostfwd=tcp::$host_port-:$guest_port")
                    print_status "INFO" "Port forward: $host_port -> $guest_port"
                    ((net_id++))
                fi
            fi
        done
    fi

    # Create directories
    mkdir -p "$VM_DIR/logs"
    mkdir -p "$VM_DIR/pids"
    mkdir -p "$VM_DIR/monitors"
    
    local log_file="$VM_DIR/logs/$VM_NAME.log"
    local pid_file="$VM_DIR/pids/$VM_NAME.pid"
    local monitor_socket="$VM_DIR/monitors/$VM_NAME.sock"
    
    # Add monitor socket
    qemu_cmd+=(-monitor "unix:$monitor_socket,server,nowait")
    
    # Display and console mode
    if [ "$open_console" = "true" ]; then
        # Open in new terminal with console
        qemu_cmd+=(-serial stdio)
        
        print_status "INFO" "Opening VM console in new terminal..."
        
        # Build the command string for the terminal
        local qemu_cmd_str="${qemu_cmd[*]}"
        
        # Detect available terminal emulator and open console
        local terminal_opened=false
        
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- bash -c "
                echo '╔═══════════════════════════════════════════════════════════╗'
                echo '║     VM Console: $VM_NAME'
                echo '╚═══════════════════════════════════════════════════════════╝'
                echo ''
                echo 'Starting VM...'
                echo 'Press Ctrl+C to stop the VM'
                echo ''
                $qemu_cmd_str 2>&1 | tee '$log_file'
                echo ''
                echo 'VM has stopped.'
                read -p 'Press Enter to close this window...'
            " &
            terminal_opened=true
        elif command -v xterm &> /dev/null; then
            xterm -T "VM Console: $VM_NAME" -e bash -c "
                echo '╔═══════════════════════════════════════════════════════════╗'
                echo '║     VM Console: $VM_NAME'
                echo '╚═══════════════════════════════════════════════════════════╝'
                echo ''
                echo 'Starting VM...'
                echo 'Press Ctrl+C to stop the VM'
                echo ''
                $qemu_cmd_str 2>&1 | tee '$log_file'
                echo ''
                echo 'VM has stopped.'
                read -p 'Press Enter to close this window...'
            " &
            terminal_opened=true
        elif command -v konsole &> /dev/null; then
            konsole -e bash -c "
                echo '╔═══════════════════════════════════════════════════════════╗'
                echo '║     VM Console: $VM_NAME'
                echo '╚═══════════════════════════════════════════════════════════╝'
                echo ''
                echo 'Starting VM...'
                echo 'Press Ctrl+C to stop the VM'
                echo ''
                $qemu_cmd_str 2>&1 | tee '$log_file'
                echo ''
                echo 'VM has stopped.'
                read -p 'Press Enter to close this window...'
            " &
            terminal_opened=true
        elif command -v xfce4-terminal &> /dev/null; then
            xfce4-terminal -T "VM Console: $VM_NAME" -e "bash -c \"
                echo '╔═══════════════════════════════════════════════════════════╗'
                echo '║     VM Console: $VM_NAME'
                echo '╚═══════════════════════════════════════════════════════════╝'
                echo ''
                echo 'Starting VM...'
                echo 'Press Ctrl+C to stop the VM'
                echo ''
                $qemu_cmd_str 2>&1 | tee '$log_file'
                echo ''
                echo 'VM has stopped.'
                read -p 'Press Enter to close this window...'
            \"" &
            terminal_opened=true
        else
            print_status "WARN" "No terminal emulator found (gnome-terminal, xterm, konsole, xfce4-terminal)"
            print_status "INFO" "Falling back to background mode"
            open_console="false"
        fi
        
        if [ "$terminal_opened" = "true" ]; then
            sleep 2
            print_status "SUCCESS" "VM console opened in new terminal window"
            print_status "INFO" "The VM is running in the new terminal"
            print_status "INFO" "Close the terminal or press Ctrl+C in it to stop the VM"
            echo
            sleep 2
            return 0
        fi
    fi
    
    # Background mode (no console)
    qemu_cmd+=(-display none)
    qemu_cmd+=(-daemonize)
    qemu_cmd+=(-pidfile "$pid_file")
    qemu_cmd+=(-serial "file:$log_file")
    
    print_status "INFO" "Starting VM in background mode..."
    
    if "${qemu_cmd[@]}" 2>>"$log_file"; then
        sleep 2
        
        if [ -f "$pid_file" ]; then
            local qemu_pid=$(cat "$pid_file")
            if kill -0 "$qemu_pid" 2>/dev/null; then
                print_status "SUCCESS" "VM '$vm_name' started successfully (PID: $qemu_pid)"
                echo
                print_status "INFO" "VM is running in background"
                print_status "INFO" "Use option 9 to open console"
                sleep 2
                return 0
            fi
        fi
        
        print_status "ERROR" "VM failed to start"
        cat "$log_file" 2>/dev/null | tail -20
        sleep 3
        return 1
    else
        print_status "ERROR" "Failed to execute QEMU"
        sleep 2
        return 1
    fi
}

# Function to manage autostart
manage_autostart() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Autostart Management (System Services)                ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    local vms=($(get_vm_list))
    
    if [ ${#vms[@]} -eq 0 ]; then
        print_status "ERROR" "No VMs available"
        sleep 2
        return 1
    fi
    
    print_status "INFO" "VMs with System Service Status:"
    echo
    
    for i in "${!vms[@]}"; do
        local vm_name="${vms[$i]}"
        local service_name="vm-${vm_name}.service"
        local service_file="/etc/systemd/system/$service_name"
        
        local status_display="${RED}Disabled${RESET}"
        local service_status=""
        
        # Check if service exists and is enabled
        if sudo test -f "$service_file" 2>/dev/null; then
            if sudo systemctl is-enabled "$service_name" &>/dev/null; then
                status_display="${GREEN}Enabled${RESET}"
                
                # Check if service is running
                if sudo systemctl is-active "$service_name" &>/dev/null; then
                    service_status=" ${GREEN}[Running]${RESET}"
                else
                    service_status=" ${YELLOW}[Stopped]${RESET}"
                fi
            else
                status_display="${YELLOW}Service exists but not enabled${RESET}"
            fi
        fi
        
        printf "  ${BOLD}%2d)${RESET} %-20s Status: %b%b\n" $((i+1)) "$vm_name" "$status_display" "$service_status"
    done
    
    echo
    echo -e "${BOLD}${CYAN}Options:${RESET}"
    echo "  1-${#vms[@]}) Enable/Disable autostart for a VM"
    echo "  A) Enable autostart for all VMs"
    echo "  D) Disable autostart for all VMs"
    echo "  S) Show detailed service status"
    echo "  R) Restart a service"
    echo "  0) Back to main menu"
    echo
    
    read -p "$(print_status "INPUT" "Enter your choice: ")" choice
    
    if [[ "$choice" == "0" ]]; then
        return 0
    elif [[ "$choice" =~ ^[Aa]$ ]]; then
        enable_all_autostart
        sleep 3
        manage_autostart
    elif [[ "$choice" =~ ^[Dd]$ ]]; then
        disable_all_autostart
        sleep 3
        manage_autostart
    elif [[ "$choice" =~ ^[Ss]$ ]]; then
        show_systemd_status
        read -p "Press Enter to continue..."
        manage_autostart
    elif [[ "$choice" =~ ^[Rr]$ ]]; then
        restart_service_menu
        manage_autostart
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#vms[@]} ]; then
        local selected_vm="${vms[$((choice-1))]}"
        toggle_autostart "$selected_vm"
        sleep 2
        manage_autostart
    else
        print_status "ERROR" "Invalid selection"
        sleep 2
        manage_autostart
    fi
}

# Function to toggle autostart for a VM
toggle_autostart() {
    local vm_name="$1"
    local service_name="vm-${vm_name}.service"
    local service_file="/etc/systemd/system/$service_name"
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Toggling Autostart for: %-30s║${RESET}" "$vm_name"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    # Check if service exists and is enabled
    local service_exists=false
    local service_enabled=false
    
    if sudo test -f "$service_file" 2>/dev/null; then
        service_exists=true
        if sudo systemctl is-enabled "$service_name" &>/dev/null; then
            service_enabled=true
        fi
    fi
    
    if [ "$service_enabled" = "true" ]; then
        # Disable autostart
        echo -e "${YELLOW}Current status: ${BOLD}Enabled${RESET}"
        echo -e "${YELLOW}Action: ${BOLD}Disabling autostart${RESET}"
        echo
        
        print_status "INFO" "Stopping service..."
        sudo systemctl stop "$service_name" 2>/dev/null || true
        
        print_status "INFO" "Disabling service..."
        sudo systemctl disable "$service_name" 2>/dev/null || true
        
        print_status "INFO" "Removing service files..."
        sudo rm -f "$service_file"
        rm -f "$VM_DIR/start-${vm_name}.sh"
        rm -f "$VM_DIR/stop-${vm_name}.sh"
        
        print_status "INFO" "Reloading systemd..."
        sudo systemctl daemon-reload
        
        # Update config
        AUTOSTART="false"
        save_vm_config
        
        echo
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}${BOLD}║     ✓ Autostart Disabled Successfully                     ║${RESET}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        print_status "SUCCESS" "Service removed: $service_name"
        
    else
        # Enable autostart
        if [ "$service_exists" = "true" ]; then
            echo -e "${YELLOW}Current status: ${BOLD}Service exists but not enabled${RESET}"
        else
            echo -e "${RED}Current status: ${BOLD}Disabled${RESET}"
        fi
        echo -e "${GREEN}Action: ${BOLD}Enabling autostart${RESET}"
        echo
        
        # Create service if it doesn't exist
        if [ "$service_exists" = "false" ]; then
            print_status "INFO" "Creating system-wide service..."
            create_systemd_service "$vm_name"
        else
            print_status "INFO" "Enabling existing service..."
            sudo systemctl enable "$service_name" 2>/dev/null
            sudo systemctl daemon-reload
        fi
        
        # Update config
        AUTOSTART="true"
        save_vm_config
        
        echo
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}${BOLD}║     ✓ Autostart Enabled Successfully                      ║${RESET}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        print_status "SUCCESS" "Service: $service_name"
        print_status "INFO" "Location: /etc/systemd/system/$service_name"
        echo
        print_status "INFO" "Control commands:"
        echo -e "  ${GREEN}sudo systemctl start $service_name${RESET}   - Start VM"
        echo -e "  ${GREEN}sudo systemctl stop $service_name${RESET}    - Stop VM"
        echo -e "  ${GREEN}sudo systemctl status $service_name${RESET}  - Check status"
        echo
        print_status "SUCCESS" "VM will start automatically on boot!"
    fi
}

# Function to enable autostart for all VMs
enable_all_autostart() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Enabling Autostart for All VMs                        ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    local vms=($(get_vm_list))
    local enabled=0
    local failed=0
    
    for vm_name in "${vms[@]}"; do
        echo -e "${CYAN}Processing: ${BOLD}$vm_name${RESET}"
        
        if load_vm_config "$vm_name" 2>/dev/null; then
            local service_name="vm-${vm_name}.service"
            local service_file="/etc/systemd/system/$service_name"
            
            # Create service if it doesn't exist
            if ! sudo test -f "$service_file" 2>/dev/null; then
                create_systemd_service "$vm_name"
            else
                # Enable if not enabled
                if ! sudo systemctl is-enabled "$service_name" &>/dev/null; then
                    sudo systemctl enable "$service_name" 2>/dev/null
                    print_status "SUCCESS" "Service enabled: $service_name"
                else
                    print_status "INFO" "Already enabled: $service_name"
                fi
            fi
            
            # Update config
            AUTOSTART="true"
            save_vm_config
            
            ((enabled++))
        else
            print_status "ERROR" "Failed to load config for $vm_name"
            ((failed++))
        fi
        
        echo
    done
    
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║     Autostart Setup Complete                               ║${RESET}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    print_status "SUCCESS" "Enabled: $enabled, Failed: $failed"
    echo
    print_status "INFO" "All VMs will start automatically on boot!"
    print_status "INFO" "Control with: sudo systemctl start/stop vm-NAME"
}

# Function to disable autostart for all VMs
disable_all_autostart() {
    echo
    echo -e "${BOLD}${YELLOW}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${YELLOW}║     Disabling Autostart for All VMs                       ║${RESET}"
    echo -e "${BOLD}${YELLOW}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    local service_dir="/etc/systemd/system"
    local disabled=0
    
    # Find all vm-*.service files
    for service_file in "$service_dir"/vm-*.service; do
        if sudo test -f "$service_file" 2>/dev/null; then
            local service_name=$(basename "$service_file")
            local vm_name=$(echo "$service_name" | sed 's/vm-\(.*\)\.service/\1/')
            
            echo -e "${YELLOW}Disabling: ${BOLD}$vm_name${RESET}"
            
            sudo systemctl stop "$service_name" 2>/dev/null || true
            sudo systemctl disable "$service_name" 2>/dev/null || true
            sudo rm -f "$service_file"
            rm -f "$VM_DIR/start-${vm_name}.sh"
            rm -f "$VM_DIR/stop-${vm_name}.sh"
            
            # Update config
            if load_vm_config "$vm_name" 2>/dev/null; then
                AUTOSTART="false"
                save_vm_config
            fi
            
            ((disabled++))
        fi
    done
    
    sudo systemctl daemon-reload
    
    echo
    if [ $disabled -gt 0 ]; then
        print_status "SUCCESS" "Disabled $disabled service(s)"
    else
        print_status "INFO" "No services found to disable"
    fi
}

# Function to restart service menu
restart_service_menu() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     Restart Service                                        ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    local vms=($(get_vm_list))
    
    print_status "INFO" "Select VM to restart:"
    echo
    
    for i in "${!vms[@]}"; do
        printf "  ${BOLD}%2d)${RESET} %s\n" $((i+1)) "${vms[$i]}"
    done
    
    echo
    read -p "$(print_status "INPUT" "Enter VM number (0 to cancel): ")" vm_num
    
    if [[ "$vm_num" == "0" ]]; then
        return 0
    fi
    
    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le ${#vms[@]} ]; then
        local selected_vm="${vms[$((vm_num-1))]}"
        local service_name="vm-${selected_vm}.service"
        
        echo
        echo -e "${CYAN}Restarting service: ${BOLD}$service_name${RESET}"
        echo
        
        if sudo systemctl restart "$service_name" 2>/dev/null; then
            sleep 2
            if sudo systemctl is-active "$service_name" &>/dev/null; then
                print_status "SUCCESS" "Service restarted successfully"
            else
                print_status "ERROR" "Service failed to start"
                echo
                print_status "INFO" "Check status with:"
                echo -e "  ${DIM}sudo systemctl status $service_name${RESET}"
            fi
        else
            print_status "ERROR" "Failed to restart service"
        fi
        
        sleep 2
    else
        print_status "ERROR" "Invalid selection"
        sleep 2
    fi
}

# Function to create systemd service for a VM
create_systemd_service() {
    local vm_name="$1"
    
    if ! load_vm_config "$vm_name"; then
        return 1
    fi
    
    local service_name="vm-${vm_name}.service"
    local novnc_service_name="vm-${vm_name}-novnc.service"
    local service_dir="/etc/systemd/system"
    local service_file="$service_dir/$service_name"
    local novnc_service_file="$service_dir/$novnc_service_name"
    
    print_status "INFO" "Creating system-wide service: $service_name"
    
    # Create the VM service file (requires root)
    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=VM - $vm_name
After=network.target

[Service]
Type=forking
ExecStart=$VM_DIR/start-${vm_name}.sh
ExecStop=$VM_DIR/stop-${vm_name}.sh
PIDFile=$VM_DIR/pids/${vm_name}.pid
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create noVNC service if VNC is configured
    if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
        print_status "INFO" "Creating noVNC service: $novnc_service_name"
        
        sudo tee "$novnc_service_file" > /dev/null <<EOF
[Unit]
Description=noVNC Web Console for VM - $vm_name
After=network.target vm-${vm_name}.service
BindsTo=vm-${vm_name}.service
PartOf=vm-${vm_name}.service

[Service]
Type=simple
ExecStart=$VM_DIR/start-novnc-${vm_name}.sh
ExecStop=$VM_DIR/stop-novnc-${vm_name}.sh
PIDFile=$VM_DIR/pids/${vm_name}-novnc.pid
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        print_status "SUCCESS" "noVNC service created"
        print_status "INFO" "noVNC will auto-start/stop with VM"
    fi
    
    # Create start script
    cat > "$VM_DIR/start-${vm_name}.sh" <<EOFSTART
#!/bin/bash
# VM Manager - Start script for $vm_name

VM_DIR="$VM_DIR"
VM_NAME="$vm_name"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
MEMORY="${MEMORY:-2048}"
CPUS="${CPUS:-2}"
SSH_PORT="${SSH_PORT:-2222}"
CPU_MODEL="${CPU_MODEL:-host}"
VNC_PORT="${VNC_PORT:-}"
OS_TYPE="${OS_TYPE:-}"
DISK_SIZE="${DISK_SIZE:-20G}"
PORT_FORWARDS="${PORT_FORWARDS:-}"
SMBIOS_MANUFACTURER="${SMBIOS_MANUFACTURER:-VM}"
SMBIOS_PRODUCT="${SMBIOS_PRODUCT:-VM}"
SMBIOS_VERSION="${SMBIOS_VERSION:-1.0}"

# Check if already running
if pgrep -f "vm-\$VM_NAME" >/dev/null 2>&1; then
    echo "VM \$VM_NAME is already running"
    exit 0
fi

# Build QEMU command
qemu_cmd=(qemu-system-x86_64)

# Machine type
machine_type=\$(qemu-system-x86_64 -machine help 2>/dev/null | grep -E "^pc-i440fx" | head -1 | awk '{print \$1}')
machine_type="\${machine_type:-pc}"

qemu_cmd+=(-machine "\$machine_type")
qemu_cmd+=(-name "VM-\$VM_NAME,process=vm-\$VM_NAME")

# KVM if available
if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    qemu_cmd+=(-enable-kvm)
    qemu_cmd+=(-cpu "\${CPU_MODEL}")
else
    qemu_cmd+=(-cpu qemu64)
fi

# Basic config
qemu_cmd+=(
    -m "\$MEMORY"
    -smp "\$CPUS"
)

# Smart boot detection
is_first_boot=true
is_installing=false
boot_marker="\$VM_DIR/.\$VM_NAME.installed"
reboot_marker="\$VM_DIR/.\$VM_NAME.rebooted"
uptime_marker="\$VM_DIR/.\$VM_NAME.uptime"

# Check installation and reboot status
if [ -f "\$reboot_marker" ]; then
    is_first_boot=false
    is_installing=false
elif [ -f "\$boot_marker" ]; then
    # Installation in progress - check if this is a fresh reboot
    if [ -f "\$uptime_marker" ]; then
        marker_age=\$(($(date +%s) - $(stat -c%Y "\$uptime_marker" 2>/dev/null || echo "0")))
        if [ "\$marker_age" -gt 120 ]; then
            # Old marker (> 2 min), this is a reboot - detach ISO
            touch "\$reboot_marker"
            is_first_boot=false
            is_installing=false
            echo "Installation complete detected - ISO will be detached"
        else
            # Fresh marker, still in same boot session
            is_first_boot=false
            is_installing=true
        fi
    else
        # No uptime marker yet
        touch "\$uptime_marker"
        is_first_boot=false
        is_installing=true
    fi
fi

# Disk configuration based on OS type
if [[ "\$OS_TYPE" == "proxmox" ]]; then
    # Proxmox VM
    proxmox_disk="\$VM_DIR/\$VM_NAME-disk.qcow2"
    
    # Create disk if doesn't exist
    if [ ! -f "\$proxmox_disk" ]; then
        qemu-img create -f qcow2 "\$proxmox_disk" "\$DISK_SIZE" >/dev/null 2>&1
    fi
    
    # Check disk size to detect installation
    if [ -f "\$proxmox_disk" ]; then
        disk_size=\$(stat -c%s "\$proxmox_disk" 2>/dev/null || echo "0")
        if [ "\$disk_size" -gt 1000000000 ] && [ ! -f "\$boot_marker" ]; then
            touch "\$boot_marker"
            touch "\$uptime_marker"
        fi
    fi
    
    if [ "\$is_first_boot" = true ]; then
        # First boot - ISO installer
        qemu_cmd+=(
            -drive "file=\$IMG_FILE,media=cdrom,readonly=on,index=0"
            -drive "file=\$proxmox_disk,format=qcow2,if=virtio,cache=writeback,index=1"
            -boot order=d,menu=on
        )
        echo "First boot - Booting from ISO installer"
    elif [ "\$is_installing" = true ]; then
        # Installation phase - keep ISO attached
        qemu_cmd+=(
            -drive "file=\$IMG_FILE,media=cdrom,readonly=on,index=0"
            -drive "file=\$proxmox_disk,format=qcow2,if=virtio,cache=writeback,index=1"
            -boot order=c,menu=on
        )
        echo "Installation phase - ISO still attached"
    else
        # Installed and rebooted - boot from disk only
        qemu_cmd+=(
            -drive "file=\$proxmox_disk,format=qcow2,if=virtio,cache=writeback"
            -boot order=c,menu=on
        )
        echo "Booting from installed system (ISO detached)"
    fi
else
    # Check if this is an ISO-based installation
    has_iso=false
    if [[ "\$IMG_FILE" == *".iso"* ]] || [[ "\$IMG_FILE" == *".iso_cache"* ]]; then
        has_iso=true
    fi
    
    if [ "\$has_iso" = true ]; then
        # Custom ISO installation
        install_disk="\$VM_DIR/\$VM_NAME-disk.qcow2"
        
        # Create disk if doesn't exist
        if [ ! -f "\$install_disk" ]; then
            qemu-img create -f qcow2 "\$install_disk" "\$DISK_SIZE" >/dev/null 2>&1
        fi
        
        # Check disk size to detect installation
        if [ -f "\$install_disk" ]; then
            disk_size=\$(stat -c%s "\$install_disk" 2>/dev/null || echo "0")
            if [ "\$disk_size" -gt 2000000000 ] && [ ! -f "\$boot_marker" ]; then
                touch "\$boot_marker"
                touch "\$uptime_marker"
            fi
        fi
        
        if [ "\$is_first_boot" = true ]; then
            # First boot - ISO installer
            qemu_cmd+=(
                -drive "file=\$IMG_FILE,media=cdrom,readonly=on,index=0"
                -drive "file=\$install_disk,format=qcow2,if=virtio,cache=writeback,index=1"
                -boot order=d,menu=on
            )
            echo "First boot - Booting from ISO installer"
        elif [ "\$is_installing" = true ]; then
            # Installation phase - keep ISO attached
            qemu_cmd+=(
                -drive "file=\$IMG_FILE,media=cdrom,readonly=on,index=0"
                -drive "file=\$install_disk,format=qcow2,if=virtio,cache=writeback,index=1"
                -boot order=c,menu=on
            )
            echo "Installation phase - ISO still attached"
        else
            # Installed and rebooted - boot from disk only
            qemu_cmd+=(
                -drive "file=\$install_disk,format=qcow2,if=virtio,cache=writeback"
                -boot order=c,menu=on
            )
            echo "Booting from installed system (ISO detached)"
        fi
    else
        # Cloud-init image (pre-installed)
        qemu_cmd+=(
            -drive "file=\$IMG_FILE,format=qcow2,if=virtio,cache=writeback"
            -drive "file=\$SEED_FILE,format=raw,if=virtio"
            -boot order=c,menu=on
        )
        echo "Booting from cloud-init image"
        touch "\$boot_marker"
    fi
fi

# Network with port forwards
network_config="user,id=n0,hostfwd=tcp::\$SSH_PORT-:22"

# Add additional port forwards if configured
if [ -n "\$PORT_FORWARDS" ]; then
    IFS=',' read -ra forwards <<< "\$PORT_FORWARDS"
    for forward in "\${forwards[@]}"; do
        forward=\$(echo "\$forward" | xargs)
        if [[ "\$forward" =~ ^([0-9]+):([0-9]+)\$ ]]; then
            host_port="\${BASH_REMATCH[1]}"
            guest_port="\${BASH_REMATCH[2]}"
            network_config="\$network_config,hostfwd=tcp::\$host_port-:\$guest_port"
            echo "Port forward: \$host_port -> \$guest_port"
        fi
    done
fi

qemu_cmd+=(
    -device virtio-net-pci,netdev=n0
    -netdev "\$network_config"
)

# SMBIOS branding - Use configured values
SMBIOS_MANUFACTURER="${SMBIOS_MANUFACTURER:-VM}"
SMBIOS_PRODUCT="${SMBIOS_PRODUCT:-VM}"
SMBIOS_VERSION="${SMBIOS_VERSION:-1.0}"

qemu_cmd+=(
    -smbios "type=0,vendor=\$SMBIOS_MANUFACTURER,version=\$SMBIOS_VERSION"
    -smbios "type=1,manufacturer=\$SMBIOS_MANUFACTURER,product=\$SMBIOS_PRODUCT,version=\$SMBIOS_VERSION,serial=\$VM_NAME-\$(date +%s)"
    -smbios "type=2,manufacturer=\$SMBIOS_MANUFACTURER,product=\$SMBIOS_PRODUCT Motherboard,version=\$SMBIOS_VERSION"
)

# VNC configuration
if [ -n "\$VNC_PORT" ]; then
    vnc_display=\$((VNC_PORT - 5900))
    qemu_cmd+=(-vnc "0.0.0.0:\$vnc_display")
else
    qemu_cmd+=(-display none)
fi

# Background mode
qemu_cmd+=(-daemonize)
qemu_cmd+=(-pidfile "\$VM_DIR/pids/\$VM_NAME.pid")
qemu_cmd+=(-serial "file:\$VM_DIR/logs/\$VM_NAME.log")

# Performance
qemu_cmd+=(
    -device virtio-balloon-pci
    -object rng-random,filename=/dev/urandom,id=rng0
    -device virtio-rng-pci,rng=rng0
    -device qemu-xhci,id=xhci
    -device usb-tablet
)

# Sound for non-Proxmox VMs
if [[ "\$OS_TYPE" != "proxmox" ]]; then
    qemu_cmd+=(
        -device intel-hda
        -device hda-duplex
    )
fi

# Create directories
mkdir -p "\$VM_DIR/pids"
mkdir -p "\$VM_DIR/logs"

# Start VM
"\${qemu_cmd[@]}" 2>>"\$VM_DIR/logs/\$VM_NAME.log"

if [ \$? -eq 0 ]; then
    echo "VM \$VM_NAME started successfully"
    sleep 2
    exit 0
else
    echo "Failed to start VM \$VM_NAME"
    exit 1
fi
EOFSTART
    
    # Create stop script
    cat > "$VM_DIR/stop-${vm_name}.sh" <<EOFSTOP
#!/bin/bash
# VM Manager - Stop script for $vm_name

VM_NAME="$vm_name"
VM_DIR="$VM_DIR"

# Find and kill all processes
pids=\$(pgrep -f "vm-\$VM_NAME" 2>/dev/null || true)

if [ -n "\$pids" ]; then
    echo "Stopping VM \$VM_NAME (PIDs: \$pids)"
    for pid in \$pids; do
        kill -9 "\$pid" 2>/dev/null || true
    done
    echo "VM \$VM_NAME stopped"
else
    echo "VM \$VM_NAME is not running"
fi

# Clean up PID file
rm -f "\$VM_DIR/pids/\$VM_NAME.pid"

exit 0
EOFSTOP
    
    # Create noVNC start script if VNC is configured
    if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
        cat > "$VM_DIR/start-novnc-${vm_name}.sh" <<EOFNOVNCSTART
#!/bin/bash
# VM Manager - noVNC start script for $vm_name

VM_NAME="$vm_name"
VM_DIR="$VM_DIR"
VNC_PORT="$VNC_PORT"
NOVNC_PORT="$NOVNC_PORT"
VNC_USERNAME="${VNC_USERNAME:-}"
VNC_PASSWORD="${VNC_PASSWORD:-}"

# Add user local bin to PATH
export PATH="\$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Wait for VM to be ready and VNC port to be listening
echo "Waiting for VM to start and VNC to be ready..."
max_wait=30
waited=0

while [ \$waited -lt \$max_wait ]; do
    # Check if VM is running
    if pgrep -f "vm-\$VM_NAME" >/dev/null 2>&1; then
        # VM is running, check if VNC port is listening
        if ss -tln 2>/dev/null | grep -q ":\$VNC_PORT " || netstat -tln 2>/dev/null | grep -q ":\$VNC_PORT "; then
            echo "VM and VNC are ready!"
            break
        fi
    fi
    
    sleep 1
    ((waited++))
done

if [ \$waited -ge \$max_wait ]; then
    echo "WARNING: VM or VNC not ready after \${max_wait}s, starting noVNC anyway..."
fi

# Check if VM is running
if ! pgrep -f "vm-\$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM \$VM_NAME is not running, cannot start noVNC"
    exit 1
fi

# Find websockify
websockify_cmd=""
if command -v websockify &> /dev/null; then
    websockify_cmd="websockify"
elif [ -f "\$HOME/.local/bin/websockify" ]; then
    websockify_cmd="\$HOME/.local/bin/websockify"
elif [ -f "/usr/bin/websockify" ]; then
    websockify_cmd="/usr/bin/websockify"
fi

if [ -z "\$websockify_cmd" ]; then
    echo "websockify not found, installing..."
    if command -v pip3 &> /dev/null; then
        pip3 install websockify --user
        export PATH="\$HOME/.local/bin:\$PATH"
        websockify_cmd="\$HOME/.local/bin/websockify"
    else
        echo "ERROR: Cannot install websockify (pip3 not found)"
        exit 1
    fi
fi

# Find noVNC directory
novnc_dir=""
for dir in "\$VM_DIR/novnc" "\$HOME/.novnc" "/usr/share/novnc"; do
    if [ -d "\$dir" ] && [ -f "\$dir/vnc.html" ]; then
        novnc_dir="\$dir"
        break
    fi
done

if [ -z "\$novnc_dir" ]; then
    echo "noVNC not found, installing to \$VM_DIR/novnc..."
    mkdir -p "\$VM_DIR/novnc"
    if command -v git &> /dev/null; then
        git clone --depth 1 https://github.com/novnc/noVNC.git "\$VM_DIR/novnc"
    else
        echo "ERROR: Cannot install noVNC (git not found)"
        exit 1
    fi
    novnc_dir="\$VM_DIR/novnc"
fi

# Check if already running
if [ -f "\$VM_DIR/pids/\$VM_NAME-novnc.pid" ]; then
    old_pid=\$(cat "\$VM_DIR/pids/\$VM_NAME-novnc.pid")
    if kill -0 "\$old_pid" 2>/dev/null; then
        echo "noVNC already running for \$VM_NAME (PID: \$old_pid)"
        exit 0
    fi
fi

# Create directories
mkdir -p "\$VM_DIR/logs"
mkdir -p "\$VM_DIR/pids"
mkdir -p "\$VM_DIR/web/\$VM_NAME"

# Copy noVNC files
novnc_source=""
for dir in "\$VM_DIR/novnc" "\$HOME/.novnc" "/usr/share/novnc"; do
    if [ -d "\$dir" ] && [ -f "\$dir/vnc.html" ]; then
        novnc_source="\$dir"
        break
    fi
done

if [ -n "\$novnc_source" ]; then
    for item in "\$novnc_source"/*; do
        basename_item=\$(basename "\$item")
        if [ ! -e "\$VM_DIR/web/\$VM_NAME/\$basename_item" ]; then
            ln -sf "\$item" "\$VM_DIR/web/\$VM_NAME/\$basename_item" 2>/dev/null || cp -r "\$item" "\$VM_DIR/web/\$VM_NAME/\$basename_item" 2>/dev/null
        fi
    done
fi

# Authentication info
if [ -n "\$VNC_USERNAME" ] && [ -n "\$VNC_PASSWORD" ]; then
    echo "VNC authentication enabled (User: \$VNC_USERNAME) - client-side validation"
else
    echo "WARNING: VNC authentication disabled - anyone can access"
fi

# Start websockify - simple mode without token plugin
echo "Starting websockify for \$VM_NAME..."
echo "noVNC Port: \$NOVNC_PORT -> VNC Port: \$VNC_PORT"

"\$websockify_cmd" \\
    --web="\$VM_DIR/web/\$VM_NAME" \\
    --log-file="\$VM_DIR/logs/\$VM_NAME-novnc.log" \\
    "0.0.0.0:\$NOVNC_PORT" \\
    "localhost:\$VNC_PORT" \\
    >> "\$VM_DIR/logs/\$VM_NAME-novnc.log" 2>&1 &

novnc_pid=\$!

# Save PID
echo "\$novnc_pid" > "\$VM_DIR/pids/\$VM_NAME-novnc.pid"

# Wait and verify
sleep 2

if kill -0 "\$novnc_pid" 2>/dev/null; then
    echo "noVNC started successfully for \$VM_NAME (PID: \$novnc_pid)"
    echo "Access at: http://localhost:\$NOVNC_PORT/vnc.html"
    exit 0
else
    echo "ERROR: noVNC failed to start for \$VM_NAME"
    cat "\$VM_DIR/logs/\$VM_NAME-novnc.log" | tail -10
    exit 1
fi
EOFNOVNCSTART

        # Create noVNC stop script
        cat > "$VM_DIR/stop-novnc-${vm_name}.sh" <<EOFNOVNCSTOP
#!/bin/bash
# VM Manager - noVNC stop script for $vm_name

VM_NAME="$vm_name"
VM_DIR="$VM_DIR"

pid_file="\$VM_DIR/pids/\$VM_NAME-novnc.pid"

if [ -f "\$pid_file" ]; then
    pid=\$(cat "\$pid_file")
    if kill -0 "\$pid" 2>/dev/null; then
        echo "Stopping noVNC for \$VM_NAME (PID: \$pid)"
        kill "\$pid" 2>/dev/null
        sleep 1
        # Force kill if still running
        if kill -0 "\$pid" 2>/dev/null; then
            kill -9 "\$pid" 2>/dev/null
        fi
        echo "noVNC stopped for \$VM_NAME"
    else
        echo "noVNC not running for \$VM_NAME (stale PID)"
    fi
    rm -f "\$pid_file"
else
    echo "noVNC not running for \$VM_NAME (no PID file)"
fi

exit 0
EOFNOVNCSTOP

        # Make noVNC scripts executable
        chmod +x "$VM_DIR/start-novnc-${vm_name}.sh"
        chmod +x "$VM_DIR/stop-novnc-${vm_name}.sh"
    fi
    
    # Make VM scripts executable
    chmod +x "$VM_DIR/start-${vm_name}.sh"
    chmod +x "$VM_DIR/stop-${vm_name}.sh"
    
    # Reload systemd and enable services
    sudo systemctl daemon-reload
    
    if sudo systemctl enable "$service_name" 2>/dev/null; then
        print_status "SUCCESS" "VM service created and enabled: $service_name"
        echo
        print_status "INFO" "Service location: /etc/systemd/system/$service_name"
        print_status "INFO" "Control: sudo systemctl start/stop/status $service_name"
        
        # Enable noVNC service if it exists
        if [ -n "$VNC_PORT" ] && [ -n "$NOVNC_PORT" ]; then
            if sudo systemctl enable "$novnc_service_name" 2>/dev/null; then
                print_status "SUCCESS" "noVNC service enabled: $novnc_service_name"
                print_status "INFO" "noVNC will auto-start when VM starts"
                print_status "INFO" "noVNC will auto-stop when VM stops"
                echo
                print_status "INFO" "Access noVNC at: ${GREEN}${BOLD}http://localhost:$NOVNC_PORT/vnc.html${RESET}"
            else
                print_status "WARN" "noVNC service created but could not be enabled"
            fi
        fi
        
        echo
        print_status "SUCCESS" "Services will start automatically on boot!"
    else
        print_status "WARN" "Service created but could not be enabled"
        print_status "INFO" "Try: sudo systemctl enable $service_name"
    fi
    
    return 0
}

# Function to remove systemd service for a VM
remove_systemd_service() {
    local vm_name="$1"
    local service_name="vm-${vm_name}.service"
    local novnc_service_name="vm-${vm_name}-novnc.service"
    local service_file="/etc/systemd/system/$service_name"
    local novnc_service_file="/etc/systemd/system/$novnc_service_name"
    
    # Remove noVNC service first
    if sudo test -f "$novnc_service_file" 2>/dev/null; then
        sudo systemctl stop "$novnc_service_name" 2>/dev/null || true
        sudo systemctl disable "$novnc_service_name" 2>/dev/null || true
        sudo rm -f "$novnc_service_file"
        print_status "SUCCESS" "noVNC service removed: $novnc_service_name"
        
        # Remove noVNC scripts
        rm -f "$VM_DIR/start-novnc-${vm_name}.sh"
        rm -f "$VM_DIR/stop-novnc-${vm_name}.sh"
    fi
    
    # Remove VM service
    if sudo test -f "$service_file" 2>/dev/null; then
        # Stop and disable service
        sudo systemctl stop "$service_name" 2>/dev/null || true
        sudo systemctl disable "$service_name" 2>/dev/null || true
        
        # Remove service file
        sudo rm -f "$service_file"
        
        # Remove start/stop scripts
        rm -f "$VM_DIR/start-${vm_name}.sh"
        rm -f "$VM_DIR/stop-${vm_name}.sh"
        
        # Reload systemd
        sudo systemctl daemon-reload
        
        print_status "SUCCESS" "VM service removed: $service_name"
    fi
}

# Function to show systemd service status
show_systemd_status() {
    echo
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║     System Service Status                                  ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    local service_dir="/etc/systemd/system"
    local found=0
    
    # Find all vm-*.service files
    for service_file in "$service_dir"/vm-*.service; do
        if sudo test -f "$service_file" 2>/dev/null; then
            local service_name=$(basename "$service_file")
            ((found++))
            
            echo -e "${BOLD}${CYAN}Service: $service_name${RESET}"
            echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"
            sudo systemctl status "$service_name" --no-pager 2>/dev/null || echo "  Status: Inactive"
            echo
        fi
    done
    
    if [ $found -eq 0 ]; then
        print_status "INFO" "No system services found"
        echo
        print_status "INFO" "Enable autostart for VMs to create services"
    fi
    
    echo
}

# Function to setup systemd autostart service (legacy - kept for compatibility)
setup_autostart_service() {
    print_status "INFO" "Autostart configuration updated"
    print_status "INFO" "Autostart script location:"
    echo
    echo -e "${GREEN}${BOLD}  $VM_DIR/autostart_vms.sh${RESET}"
    echo
    
    # Create a complete autostart script
    cat > "$VM_DIR/autostart_vms.sh" <<'EOFSCRIPT'
#!/bin/bash
# VM Manager - Autostart Script
# Add this script to your system startup to auto-start VMs

VM_DIR="${HOME}/vms"
LOG_FILE="$VM_DIR/logs/autostart.log"

mkdir -p "$VM_DIR/logs"
mkdir -p "$VM_DIR/pids"

echo "========================================" >> "$LOG_FILE"
echo "$(date): Starting VMs with autostart enabled" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Check if QEMU is available
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "$(date): ERROR - qemu-system-x86_64 not found" >> "$LOG_FILE"
    exit 1
fi

# Find all VMs with autostart enabled
started_count=0
failed_count=0

for conf in "$VM_DIR"/*.conf; do
    if [ -f "$conf" ]; then
        # Reset variables
        VM_NAME=""
        AUTOSTART="false"
        IMG_FILE=""
        SEED_FILE=""
        MEMORY="2048"
        CPUS="2"
        SSH_PORT="2222"
        CPU_MODEL=""
        CUSTOM_CPU_STRING=""
        PORT_FORWARDS=""
        
        # Load config
        source "$conf"
        
        # Check if autostart is enabled
        if [ "${AUTOSTART}" != "true" ]; then
            continue
        fi
        
        echo "$(date): Processing VM: $VM_NAME" >> "$LOG_FILE"
        
        # Check if already running
        if pgrep -f "vm-$VM_NAME" >/dev/null 2>&1; then
            echo "$(date): VM $VM_NAME already running, skipping" >> "$LOG_FILE"
            continue
        fi
        
        # Verify required files exist
        if [ ! -f "$IMG_FILE" ]; then
            echo "$(date): ERROR - Image file not found: $IMG_FILE" >> "$LOG_FILE"
            ((failed_count++))
            continue
        fi
        
        if [ ! -f "$SEED_FILE" ]; then
            echo "$(date): ERROR - Seed file not found: $SEED_FILE" >> "$LOG_FILE"
            ((failed_count++))
            continue
        fi
        
        echo "$(date): Starting VM: $VM_NAME" >> "$LOG_FILE"
        
        # Build QEMU command for background mode
        qemu_cmd=(qemu-system-x86_64)
        
        # Machine type
        machine_type=$(qemu-system-x86_64 -machine help 2>/dev/null | grep -E "^pc-i440fx" | head -1 | awk '{print $1}')
        machine_type="${machine_type:-pc}"
        
        qemu_cmd+=(-machine "$machine_type")
        qemu_cmd+=(-name "VM-$VM_NAME,process=vm-$VM_NAME")
        
        # KVM if available
        if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
            qemu_cmd+=(-enable-kvm)
            if [ -n "$CPU_MODEL" ] && [ "$CPU_MODEL" != "QEMU Default (qemu64)" ]; then
                qemu_cmd+=(-cpu "${CPU_MODEL}")
            else
                qemu_cmd+=(-cpu host)
            fi
        else
            qemu_cmd+=(-cpu qemu64)
        fi
        
        # Basic config
        qemu_cmd+=(
            -m "${MEMORY:-2048}"
            -smp "${CPUS:-2}"
            -drive "file=$IMG_FILE,format=qcow2,if=virtio"
            -drive "file=$SEED_FILE,format=raw,if=virtio"
            -boot order=c
            -device virtio-net-pci,netdev=n0
            -netdev "user,id=n0,hostfwd=tcp::${SSH_PORT:-2222}-:22"
        )
        
        # SMBIOS branding - Use configured values
        qemu_cmd+=(
            -smbios "type=0,vendor=${SMBIOS_MANUFACTURER:-VM},version=${SMBIOS_VERSION:-1.0}"
            -smbios "type=1,manufacturer=${SMBIOS_MANUFACTURER:-VM},product=${SMBIOS_PRODUCT:-VM},version=${SMBIOS_VERSION:-1.0},serial=$VM_NAME-$(date +%s)"
            -smbios "type=2,manufacturer=${SMBIOS_MANUFACTURER:-VM},product=${SMBIOS_PRODUCT:-VM} Motherboard,version=${SMBIOS_VERSION:-1.0}"
        )
        
        # Background mode
        qemu_cmd+=(-display none)
        qemu_cmd+=(-daemonize)
        qemu_cmd+=(-pidfile "$VM_DIR/pids/$VM_NAME.pid")
        qemu_cmd+=(-serial "file:$VM_DIR/logs/$VM_NAME.log")
        
        # Performance
        qemu_cmd+=(
            -device virtio-balloon-pci
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0
        )
        
        # Start VM
        if "${qemu_cmd[@]}" 2>>"$VM_DIR/logs/$VM_NAME.log"; then
            echo "$(date): ✓ VM $VM_NAME started successfully (PID: $(cat "$VM_DIR/pids/$VM_NAME.pid" 2>/dev/null || echo "unknown"))" >> "$LOG_FILE"
            ((started_count++))
        else
            echo "$(date): ✗ Failed to start VM $VM_NAME" >> "$LOG_FILE"
            ((failed_count++))
        fi
        
        # Small delay between VM starts
        sleep 2
    fi
done

echo "========================================" >> "$LOG_FILE"
echo "$(date): Autostart complete - Started: $started_count, Failed: $failed_count" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
EOFSCRIPT
    
    chmod +x "$VM_DIR/autostart_vms.sh"
    
    print_status "SUCCESS" "Autostart script created: $VM_DIR/autostart_vms.sh"
}

# Function to manage ISO cache
manage_iso_cache() {
    local cache_dir="$VM_DIR/.iso_cache"
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}${BOLD}║  ISO Cache Management                                     ║${RESET}"
        echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        
        # Check if cache directory exists
        if [ ! -d "$cache_dir" ]; then
            print_status "INFO" "No ISO cache found"
            echo
            print_status "INFO" "Cache will be created when you download your first ISO"
            echo
            print_status "INFO" "Press Enter to return to main menu..."
            read
            return
        fi
        
        # List cached ISOs
        local cached_files=($(ls -1 "$cache_dir" 2>/dev/null))
        
        if [ ${#cached_files[@]} -eq 0 ]; then
            print_status "INFO" "ISO cache is empty"
            echo
            print_status "INFO" "Cache will be populated when you create VMs"
            echo
            print_status "INFO" "Press Enter to return to main menu..."
            read
            return
        fi
        
        echo -e "${BOLD}${GREEN}Cached ISOs:${RESET}"
        echo
        
        local total_size=0
        for i in "${!cached_files[@]}"; do
            local file="${cached_files[$i]}"
            local filepath="$cache_dir/$file"
            local size=$(du -h "$filepath" 2>/dev/null | cut -f1)
            local size_bytes=$(stat -c%s "$filepath" 2>/dev/null || stat -f%z "$filepath" 2>/dev/null || echo "0")
            total_size=$((total_size + size_bytes))
            
            echo -e "  ${CYAN}$((i+1)))${RESET} ${BOLD}$file${RESET}"
            echo -e "     Size: ${GREEN}$size${RESET}"
            echo
        done
        
        # Calculate total size
        local total_size_mb=$((total_size / 1024 / 1024))
        local total_size_gb=$((total_size_mb / 1024))
        
        if [ $total_size_gb -gt 0 ]; then
            echo -e "${BOLD}Total cache size: ${GREEN}${total_size_gb} GB${RESET}"
        else
            echo -e "${BOLD}Total cache size: ${GREEN}${total_size_mb} MB${RESET}"
        fi
        echo
        
        echo -e "${CYAN}${BOLD}Options:${RESET}"
        echo -e "  ${RED}1)${RESET} Clear all cache"
        echo -e "  ${RED}2)${RESET} Delete specific ISO"
        echo -e "  ${BLUE}3)${RESET} View cache location"
        echo -e "  ${WHITE}0)${RESET} Back to main menu"
        echo
        
        read -p "$(print_status "INPUT" "Enter your choice: ")" choice
        
        case $choice in
            1)
                echo
                read -p "$(print_status "WARN" "Are you sure you want to clear all cache? (y/N): ")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    rm -rf "$cache_dir"/*
                    print_status "SUCCESS" "Cache cleared successfully"
                    echo
                    print_status "INFO" "ISOs will be re-downloaded when needed"
                    sleep 2
                else
                    print_status "INFO" "Operation cancelled"
                    sleep 1
                fi
                ;;
            2)
                echo
                read -p "$(print_status "INPUT" "Enter ISO number to delete (1-${#cached_files[@]}): ")" iso_num
                if [[ "$iso_num" =~ ^[0-9]+$ ]] && [ "$iso_num" -ge 1 ] && [ "$iso_num" -le ${#cached_files[@]} ]; then
                    local file_to_delete="${cached_files[$((iso_num-1))]}"
                    echo
                    read -p "$(print_status "WARN" "Delete $file_to_delete? (y/N): ")" confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        rm -f "$cache_dir/$file_to_delete"
                        print_status "SUCCESS" "ISO deleted from cache"
                        echo
                        print_status "INFO" "It will be re-downloaded when needed"
                        sleep 2
                    else
                        print_status "INFO" "Operation cancelled"
                        sleep 1
                    fi
                else
                    print_status "ERROR" "Invalid ISO number"
                    sleep 2
                fi
                ;;
            3)
                echo
                print_status "INFO" "Cache location: $cache_dir"
                echo
                print_status "INFO" "You can manually manage files in this directory"
                echo
                print_status "INFO" "Press Enter to continue..."
                read
                ;;
            0)
                return
                ;;
            *)
                print_status "ERROR" "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Main menu function
main_menu() {
    while true; do
        display_header
        
        local vms=()
        local vm_list_output
        vm_list_output=$(get_vm_list)
        
        if [ -n "$vm_list_output" ]; then
            readarray -t vms <<< "$vm_list_output"
        fi
        
        local vm_count=${#vms[@]}
        
        # Display VM list with enhanced visuals
        if [ $vm_count -gt 0 ]; then
            echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${BOLD}${CYAN}║  Virtual Machines                      Total: %-11s║${RESET}" "$vm_count"
            echo -e "${BOLD}${CYAN}╠═══════════════════════════════════════════════════════════╣${RESET}"
            
            for i in "${!vms[@]}"; do
                local vm_name="${vms[$i]}"
                local status_icon="${RED}●${RESET}"
                local status_text="${RED}Stopped${RESET}"
                
                # Check if running (with error handling)
                if is_vm_running "$vm_name" 2>/dev/null; then
                    status_icon="${GREEN}●${RESET}"
                    status_text="${GREEN}Running${RESET}"
                fi
                
                printf "${BOLD}${CYAN}║${RESET}  ${BOLD}%2d)${RESET} %-25s %b %-15b ${BOLD}${CYAN}║${RESET}\n" $((i+1)) "$vm_name" "$status_icon" "$status_text"
            done
            
            echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
            echo
        else
            echo -e "${BOLD}${YELLOW}╔═══════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${BOLD}${YELLOW}║  No VMs Found - Create Your First VM!                     ║${RESET}"
            echo -e "${BOLD}${YELLOW}╚═══════════════════════════════════════════════════════════╝${RESET}"
            echo
        fi
        
        # Display menu options with enhanced design
        echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║  Main Menu                                                 ║${RESET}"
        echo -e "${BOLD}${CYAN}╠═══════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${BOLD}${CYAN}║${RESET}  ${GREEN}1)${RESET} Create a new VM                                     ${BOLD}${CYAN}║${RESET}"
        
        if [ $vm_count -gt 0 ]; then
            echo -e "${BOLD}${CYAN}║${RESET}  ${GREEN}2)${RESET} Start a VM                                         ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${YELLOW}3)${RESET} Stop a VM                                          ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${BLUE}4)${RESET} Show VM info                                       ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${BLUE}5)${RESET} Edit VM configuration                              ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${BLUE}6)${RESET} Clone a VM                                         ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${RED}7)${RESET} Delete a VM                                        ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${MAGENTA}8)${RESET} Manage Autostart                                   ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${BLUE}9)${RESET} Open VM Console                                    ${BOLD}${CYAN}║${RESET}"
            echo -e "${BOLD}${CYAN}║${RESET}  ${GREEN}m)${RESET} Mark VM as Installed (detach ISO)                 ${BOLD}${CYAN}║${RESET}"
        fi
        
        echo -e "${BOLD}${CYAN}║${RESET}  ${MAGENTA}i)${RESET} Install/Check noVNC                                ${BOLD}${CYAN}║${RESET}"
        echo -e "${BOLD}${CYAN}║${RESET}  ${BLUE}c)${RESET} Manage ISO Cache                                   ${BOLD}${CYAN}║${RESET}"
        echo -e "${BOLD}${CYAN}║${RESET}  ${WHITE}0)${RESET} Exit ${GREEN}(VMs keep running in background)${RESET}          ${BOLD}${CYAN}║${RESET}"
        echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo
        
        read -p "$(print_status "INPUT" "Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_vm
                ;;
            2)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number to start (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        start_vm "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available. Create a VM first (option 1)"
                    sleep 2
                fi
                ;;
            3)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number to stop (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            4)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_info "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            5)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number to edit (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        edit_vm_config "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            6)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number to clone (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        clone_vm "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            7)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number to delete (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        delete_vm "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            8)
                if [ $vm_count -gt 0 ]; then
                    manage_autostart
                else
                    echo
                    print_status "ERROR" "No VMs available. Create a VM first (option 1)"
                    sleep 2
                fi
                ;;
            9)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        open_vm_console "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            m|M)
                if [ $vm_count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter VM number (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        mark_vm_installed "${vms[$((vm_num-1))]}"
                    else
                        echo
                        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                        echo -e "${RED}${BOLD}║  ✗ Invalid VM Number                                      ║${RESET}"
                        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                        echo
                        print_status "ERROR" "Please enter a number between 1 and $vm_count"
                        sleep 2
                    fi
                else
                    echo
                    print_status "ERROR" "No VMs available"
                    sleep 2
                fi
                ;;
            i|I)
                echo
                print_status "INFO" "Checking noVNC installation..."
                echo
                install_novnc
                echo
                print_status "INFO" "Press Enter to continue..."
                read
                ;;
            c|C)
                manage_iso_cache
                ;;
            0)
                echo
                echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${CYAN}${BOLD}║                Thank you for using VM Manager!           ║${RESET}"
                echo -e "${CYAN}${BOLD}╠═══════════════════════════════════════════════════════════╣${RESET}"
                echo -e "${CYAN}${BOLD}║  ${GREEN}✓${CYAN} All VMs continue running in background              ${CYAN}║${RESET}"
                echo -e "${CYAN}${BOLD}║  ${GREEN}✓${CYAN} All noVNC services continue running in background   ${CYAN}║${RESET}"
                echo -e "${CYAN}${BOLD}║  ${BLUE}ℹ${CYAN} Control: sudo systemctl start/stop vm-NAME          ${CYAN}║${RESET}"
                echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                echo
                
                exit 0
                ;;
            *)
                clear
                echo
                echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${RED}${BOLD}║  ✗ Invalid Option!                                        ║${RESET}"
                echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
                echo
                print_status "ERROR" "Invalid option '$choice'. Please select a valid option."
                echo
                if [ $vm_count -gt 0 ]; then
                    print_status "INFO" "Valid options: 0-9"
                else
                    print_status "INFO" "Valid options: 0 (Exit) or 1 (Create VM)"
                fi
                echo
                sleep 2
                ;;
        esac
    done
}

# Supported OS list
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Ubuntu 20.04 LTS"]="ubuntu|focal|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|ubuntu20|ubuntu|ubuntu"
    ["Debian 11 (Bullseye)"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["Fedora 39"]="fedora|39|https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2|fedora39|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
    ["Proxmox VE 8"]="proxmox|8|https://enterprise.proxmox.com/iso/proxmox-ve_8.4-1.iso|proxmox8|proxmox|proxmox"
)

# =============================
# Main Execution
# =============================

# Initialize
clear
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║              Initializing VM Manager...                    ║${RESET}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
echo
sleep 0.3

# Check KVM support
print_status "INFO" "Checking KVM support..."
check_kvm_support
sleep 0.2

# Check dependencies
echo
check_dependencies
echo

# Initialize VM directory
mkdir -p "$VM_DIR"
print_status "SUCCESS" "VM directory: $VM_DIR"
sleep 0.3

echo
print_status "SUCCESS" "Initialization complete!"
sleep 0.5

# Start main menu
main_menu
