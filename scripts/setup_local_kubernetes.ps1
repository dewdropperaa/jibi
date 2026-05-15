<#
.SYNOPSIS
  Starts local Kubernetes with Minikube — no Docker required.

.DESCRIPTION
  Driver order (Docker is NOT used unless you pass -AllowDocker):
    1) vmware      — VMware Workstation (if vmrun.exe is installed)
    2) virtualbox  — Oracle VirtualBox
    3) hyperv      — Administrator shell + working Hyper-V

  If VirtualBox fails with "VT-X/AMD-v" but VMware VMs work, use VMware:
    minikube delete --all
    minikube start --driver=vmware

.PARAMETER AllowDocker
  If set, Minikube may use the docker driver when `docker` is on PATH.
#>

[CmdletBinding()]
param(
    [switch]$AllowDocker
)

$ErrorActionPreference = "Stop"

function Test-CommandExists([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-VBox {
    return (Test-CommandExists "VBoxManage") -or (Test-Path "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe")
}

function Test-VMware {
    $vmrunPaths = @(
        "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe",
        "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
    )
    foreach ($p in $vmrunPaths) {
        if (Test-Path $p) {
            $script:VmwareBin = Split-Path $p -Parent
            return $true
        }
    }
    return (Test-CommandExists "vmrun")
}

Write-Host "=== kubectl config (before) ===" -ForegroundColor Cyan
kubectl config view
Write-Host ""

if (-not (Test-CommandExists "minikube")) {
    Write-Error "minikube not found in PATH. Install: https://minikube.sigs.k8s.io/docs/start/"
}

$driver = $null
if (Test-VMware) {
    $driver = "vmware"
    if ($script:VmwareBin -and -not (Test-CommandExists "vmrun")) {
        $env:Path += ";$($script:VmwareBin)"
    }
    Write-Host "Using driver: vmware (VMware Workstation — no Docker)" -ForegroundColor Green
}
elseif (Test-VBox) {
    $driver = "virtualbox"
    if (-not (Test-CommandExists "VBoxManage")) {
        $env:Path += ";C:\Program Files\Oracle\VirtualBox"
    }
    Write-Host "Using driver: virtualbox" -ForegroundColor Green
}
elseif ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) {
    $driver = "hyperv"
    Write-Host "Using driver: hyperv (Administrator shell)" -ForegroundColor Yellow
}
elseif ($AllowDocker -and (Test-CommandExists "docker")) {
    $driver = "docker"
    Write-Host "Using driver: docker (-AllowDocker set)" -ForegroundColor Yellow
}
else {
    Write-Host @"

No usable Minikube driver found.

If VMware Workstation works on this PC:
  minikube delete --all
  minikube start --driver=vmware

Add VMware to PATH if vmrun is not found:
  C:\Program Files (x86)\VMware\VMware Workstation

Or skip local Kubernetes and use GitHub Actions only.

"@ -ForegroundColor Yellow
    exit 1
}

# A cluster created with virtualbox cannot be started with vmware (and vice versa).
$existing = minikube profile list -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($existing) {
    $profile = $existing.valid | Where-Object { $_.Name -eq "minikube" } | Select-Object -First 1
    if ($profile -and $profile.Config -and $profile.Config.Driver -and $profile.Config.Driver -ne $driver) {
        Write-Host "Removing existing minikube profile (driver was $($profile.Config.Driver), need $driver)..." -ForegroundColor Yellow
        & minikube delete --all
    }
}

Write-Host "Starting Minikube (driver=$driver). First run may take several minutes." -ForegroundColor Cyan
& minikube start --driver=$driver

Write-Host "`n=== kubectl ===" -ForegroundColor Green
kubectl config use-context minikube
kubectl cluster-info
kubectl get nodes

Write-Host "`nDone. kubeconfig: $env:USERPROFILE\.kube\config" -ForegroundColor Green
