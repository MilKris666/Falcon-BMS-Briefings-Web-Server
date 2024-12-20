If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Script is starting..."
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

# Define the folder containing briefing files
$BriefingFolder = "C:\Falcon BMS 4.37\User\Briefings"

# Temporary folder for deployment
$TempWebFolder = "$env:Temp\BriefingWeb"

# Port for the HTTP server
$Port = 8080


# Function to check Firewall
function RuleExists {
    param (
        [string]$RuleName
    )
    $rule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    return $null -ne $rule
}

# Check and create rule "Allow Inbound Port 8080" if it does not exist
if (-not (RuleExists -RuleName "Allow Inbound Port 8080")) {
    Write-Output "Creating rule: Allow Inbound Port 8080"
    New-NetFirewallRule -DisplayName "Allow Inbound Port 8080" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $Port `
        -Action Allow `
        -Profile Any
} else {
    Write-Output "Rule 'Allow Inbound Port 8080' already exists."
}

# Check and create rule "Allow Outbound Port 8080" if it does not exist
if (-not (RuleExists -RuleName "Allow Outbound Port 8080")) {
    Write-Output "Creating rule: Allow Outbound Port 8080"
    New-NetFirewallRule -DisplayName "Allow Outbound Port 8080" `
        -Direction Outbound `
        -Protocol TCP `
        -LocalPort $Port `
        -Action Allow `
        -Profile Any
} else {
    Write-Output "Rule 'Allow Outbound Port 8080' already exists."
}



# Function to find the latest HTML file
function Get-LatestHtmlFile {
    param (
        [string]$Folder
    )
    try {
        $latestFile = Get-ChildItem -Path $Folder -Filter "*.html" -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latestFile) {
            Write-Host "Found latest file: $($latestFile.FullName) with timestamp $($latestFile.LastWriteTime)" -ForegroundColor Cyan
        }
        return $latestFile
    } catch {
        Write-Host "Error accessing folder: $Folder" -ForegroundColor Red
        return $null
    }
}

# Function to copy the latest file
function Update-WebFolder {
    param (
        [string]$SourceFolder,
        [string]$TargetFolder
    )
    $LatestFile = Get-LatestHtmlFile -Folder $SourceFolder
    if ($LatestFile) {
        $TargetFile = "$TargetFolder\index.html"
        try {
            if ((-not (Test-Path $TargetFile)) -or ($LatestFile.LastWriteTime -gt (Get-Item $TargetFile).LastWriteTime)) {
                Write-Host "Copying latest file: '$($LatestFile.FullName)' to '$TargetFile'" -ForegroundColor Cyan
                Copy-Item -Path $LatestFile.FullName -Destination $TargetFile -Force
                Write-Host "File updated: '$($LatestFile.Name)' in target folder" -ForegroundColor Green
                return $true
            } else {
                Write-Host "No update required. The existing file is up to date." -ForegroundColor Yellow
                return $false
            }
        } catch {
            Write-Host "Error copying file: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "No files found in the source folder." -ForegroundColor Red
        return $false
    }
}

# Clean up and create the temporary folder
if (Test-Path $TempWebFolder) {
    Remove-Item -Recurse -Force $TempWebFolder
}
New-Item -ItemType Directory -Path $TempWebFolder | Out-Null

# Modified SimpleHttpServer class
Add-Type @"
using System;
using System.Net;
using System.IO;
using System.Threading;

public class SimpleHttpServer {
    private HttpListener _listener;
    private string _webFolder;

    public SimpleHttpServer(string webFolder, int port) {
        _webFolder = webFolder;
        _listener = new HttpListener();
        _listener.Prefixes.Add(string.Format("http://*:{0}/", port));
    }

    public void Start() {
        Thread serverThread = new Thread(new ThreadStart(this.Listen));
        serverThread.IsBackground = true;
        serverThread.Start();
    }

    private void Listen() {
        _listener.Start();
        Console.WriteLine("Server started. Processing requests...");
        while (_listener.IsListening) {
            try {
                HttpListenerContext context = _listener.GetContext();
                string requestUrl = context.Request.Url.LocalPath.TrimStart('/');
                string filePath = Path.Combine(_webFolder, string.IsNullOrEmpty(requestUrl) ? "index.html" : requestUrl);

                if (File.Exists(filePath)) {
                    var response = context.Response;
                    byte[] buffer = File.ReadAllBytes(filePath);
                    response.ContentType = "text/html";
                    response.ContentLength64 = buffer.Length;
                    response.OutputStream.Write(buffer, 0, buffer.Length);
                    response.OutputStream.Close();
                } else {
                    context.Response.StatusCode = 404;
                    context.Response.Close();
                }
            } catch (Exception ex) {
                Console.WriteLine("Error in HTTP server: " + ex.Message);
            }
        }
    }

    public void Stop() {
        if (_listener.IsListening) {
            _listener.Stop();
            Console.WriteLine("Server stopped.");
        }
    }
}
"@

# Main process
$server = $null
try {
    $server = New-Object SimpleHttpServer($TempWebFolder, $Port)
    $server.Start()

    while ($true) {
        Write-Host "Checking for updates and updating files..." -ForegroundColor Yellow

        # Update the files
        $needsRestart = Update-WebFolder -SourceFolder $BriefingFolder -TargetFolder $TempWebFolder

        if ($needsRestart) {
            Write-Host "Updated 'index.html'. Restart not required; server continues serving latest file." -ForegroundColor Green
        }

        # Wait 5 seconds
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Host "Error in main process: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($server -ne $null) {
        try {
            Write-Host "Stopping server..." -ForegroundColor Yellow
            $server.Stop()
        } catch {
            Write-Host "Error stopping the server: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
