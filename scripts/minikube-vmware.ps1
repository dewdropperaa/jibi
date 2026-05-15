# Starts Minikube with VMware — does not rely on vmrun being in PATH.
$vmwareDir = "C:\Program Files (x86)\VMware\VMware Workstation"
if (-not (Test-Path "$vmwareDir\vmrun.exe")) {
    $vmwareDir = "C:\Program Files\VMware\VMware Workstation"
}
if (-not (Test-Path "$vmwareDir\vmrun.exe")) {
    Write-Error "vmrun.exe not found. Install VMware Workstation."
    exit 1
}

$env:Path = "$vmwareDir;$env:Path"
& "$vmwareDir\vmrun.exe" -T ws list
& minikube start --driver=vmware @args
