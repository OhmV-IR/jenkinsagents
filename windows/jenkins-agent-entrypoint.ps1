# Entrypoint of the jenkins-agent-windows image: fetches agent.jar from the controller and runs it
# (on the JDK 25 that Chocolatey's temurin25 puts on PATH).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Write-Host "Installing UE Prerequisites"

foreach ($engine in Get-ChildItem $env:UE_ROOT -Directory) {
    $prereqPath = Join-Path $engine.FullName 'Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe'
    
    if (Test-Path $prereqPath) {
        Write-Host ('Installing prerequisites of Unreal Engine ' + $engine.Name + '...') -ForegroundColor Cyan
        $p = Start-Process -FilePath $prereqPath -ArgumentList '/quiet','/norestart' -Wait -PassThru
        
        if ($p.ExitCode -eq 0) {
            Write-Host ('Prerequisites for ' + $engine.Name + ' installed successfully.') -ForegroundColor Green
        }
        elseif ($p.ExitCode -eq 3010) {
            throw ('UEPrereqSetup_x64.exe of ' + $engine.Name + 'is causing a container restart')
        }
        else {
            throw ('UEPrereqSetup_x64.exe of ' + $engine.Name + ' failed with exit code ' + $p.ExitCode)
        }
    } else {
        Write-Warning ('Prereq installer not found for ' + $engine.Name + ' at ' + $prereqPath)
    }
}

Write-Host "Fetching agent.jar from $env:JENKINS_URL"
for ($attempt = 1; ; $attempt++) {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$env:JENKINS_URL/jnlpJars/agent.jar" -OutFile 'agent.jar'
        break
    } catch {
        if ($attempt -ge 10) { throw }
        Write-Warning "agent.jar download failed (attempt $attempt/10): $($_.Exception.Message); retrying in 5s"
        Start-Sleep -Seconds 5
    }
}

Write-Host 'Starting Jenkins Agent...'
& java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR
exit $LASTEXITCODE
