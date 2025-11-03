<#
windows.ps1
Versão aprimorada — Windows + WSL2 + setup Ubuntu (recriação do ubuntu.sh)
Autor: Felipe Alencar
#>

# --- CONFIGURAÇÕES ---
$gitUserName = "Felipe Alencar"
$gitUserEmail = "me@felipealencar.dev"

# --- VERIFICAÇÕES ---
function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Warning "⚠️  Execute este script como Administrador!"
        exit 1
    }
}
Assert-Admin

Write-Host "🚀 Iniciando FA Windows + WSL setup..." -ForegroundColor Cyan

# --- ATIVAR WSL ---
Write-Host "→ Ativando WSL2 e Virtual Machine Platform..." -ForegroundColor Yellow
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All | Out-Null
wsl --update 2>$null

# --- INSTALAR UBUNTU ---
$distros = wsl -l -q 2>$null
if ($distros -notmatch "Ubuntu") {
    Write-Host "→ Instalando Ubuntu (WSL2)..." -ForegroundColor Yellow
    wsl --install -d Ubuntu
    Write-Host "💡 Após criação de usuário, volte a rodar este script."
    exit 0
} else {
    Write-Host "✔️ Ubuntu já instalado." -ForegroundColor Green
}

# --- INSTALAR APPS WINDOWS VIA WINGET ---
function Install-WinApp {
    param($id, $name)
    if ($name -eq "Spotify" -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "→ Instalando Spotify em modo não-administrador..." -ForegroundColor Cyan
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"winget install --id=Spotify.Spotify -e --accept-package-agreements --accept-source-agreements`"" -Verb RunAsUser
        return
    }

    Write-Host "→ Instalando $name..." -ForegroundColor Cyan
    winget install --id=$id -e --accept-package-agreements --accept-source-agreements 2>$null
}

Install-WinApp "Microsoft.VisualStudioCode" "Visual Studio Code"
Install-WinApp "Docker.DockerDesktop" "Docker Desktop"
Install-WinApp "Microsoft.WindowsTerminal" "Windows Terminal"
Install-WinApp "Google.Chrome" "Google Chrome"
Install-WinApp "Brave.Brave" "Brave Browser"
Install-WinApp "DBeaver.DBeaver" "DBeaver"
Install-WinApp "Spotify.Spotify" "Spotify"

# --- EXTENSÕES DO VS CODE ---
$extensions = @(
    "dbaeumer.vscode-eslint",
    "christian-kohler.path-intellisense",
    "firsttris.vscode-jest-runner",
    "ritwickdey.LiveServer",
    "PKief.material-icon-theme",
    "dracula-theme.theme-dracula",
    "esbenp.prettier-vscode",
    "foxundermoon.shell-format",
    "waderyan.gitblame",
    "yzhang.markdown-all-in-one"
)
foreach ($ext in $extensions) {
    Write-Host "→ VSCode: $ext"
    try { code --install-extension $ext --force } catch {}
}

# --- SCRIPT DENTRO DO WSL ---
$wslScript = @"
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

GIT_NAME='$gitUserName'
GIT_EMAIL='$gitUserEmail'

sudo apt-get update -y
sudo apt-get install -y curl git wget vim nano zsh xclip unzip ca-certificates apt-transport-https gnupg lsb-release

# Git config
git config --global user.name "\$GIT_NAME"
git config --global user.email "\$GIT_EMAIL"

# Editor
git config --global core.editor vim

# SSH Key
mkdir -p ~/.ssh
if [[ ! -f ~/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -b 4096 -C "\$GIT_EMAIL" -f ~/.ssh/id_rsa -N ""
fi
eval "\$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa

# Oh My Zsh
if [[ ! -d ~/.oh-my-zsh ]]; then
  RUNZSH=no CHSH=no sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
chsh -s \$(which zsh) || true
echo "alias pbcopy='clip.exe'" >> ~/.zshrc
echo "alias pbpaste='powershell.exe Get-Clipboard -Raw'" >> ~/.zshrc

# NVM + Node
if [[ ! -d ~/.nvm ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
fi
export NVM_DIR="\$HOME/.nvm"
. "\$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default lts

# ZSH autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions || true
echo "source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc

# Fira Code
sudo apt-get install -y fonts-firacode

# Node theme
wget -O ~/.oh-my-zsh/themes/node.zsh-theme https://raw.githubusercontent.com/skuridin/oh-my-zsh-node-theme/master/node.zsh-theme
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="node"/' ~/.zshrc

# Docker (use Desktop backend)
sudo apt-get install -y docker-ce-cli docker-compose-plugin

# AWS CLI
sudo apt-get install -y awscli
curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o smp.deb
sudo dpkg -i smp.deb || true

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf || true
yes | ~/.fzf/install --all || true

echo "✅ WSL setup concluído."
"@

$tempFile = "$env:TEMP\fa-wsl2-setup.sh"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempFile, $wslScript, $utf8NoBom)

Write-Host "→ Copiando script para WSL e executando..." -ForegroundColor Cyan
wsl -d Ubuntu -- bash -c "cat > /tmp/fa-wsl2-setup.sh && chmod +x /tmp/fa-wsl2-setup.sh"
wsl -d Ubuntu -- bash -ic "/tmp/fa-wsl2-setup.sh"

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# --- TEMA DRACULA + FIRA CODE ---
Write-Host "→ Aplicando tema Dracula + Fira Code..." -ForegroundColor Magenta

# VS Code
$vscodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
if (!(Test-Path $vscodeSettingsPath)) {
    New-Item -ItemType File -Path $vscodeSettingsPath -Force | Out-Null
}
$vscodeSettings = @{
    "workbench.colorTheme" = "Dracula"
    "editor.fontFamily" = "Fira Code"
    "editor.fontLigatures" = $true
    "terminal.integrated.fontFamily" = "Fira Code"
}
$vscodeJson = $vscodeSettings | ConvertTo-Json -Depth 3
Set-Content -Path $vscodeSettingsPath -Value $vscodeJson -Encoding UTF8

# Windows Terminal
$terminalSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $terminalSettings) {
    $json = Get-Content $terminalSettings -Raw | ConvertFrom-Json
    foreach ($profile in $json.profiles.list) {
        $profile.fontFace = "Fira Code"
        $profile.colorScheme = "Dracula"
    }
    $json | ConvertTo-Json -Depth 5 | Set-Content $terminalSettings -Encoding UTF8
} else {
    Write-Warning "⚠️ Windows Terminal settings.json não encontrado."
}

Write-Host "🎨 Tema Dracula + Fira Code aplicado com sucesso!"
Write-Host "🎉 Setup completo!" -ForegroundColor Green
