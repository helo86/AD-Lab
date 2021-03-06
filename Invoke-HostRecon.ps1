function Invoke-HostRecon{

    <#
    Copied and adapted to my needs from https://github.com/dafthack/HostRecon/blob/master/HostRecon.ps1
    
    .DESCRIPTION

    This function runs a number of checks on a system to help provide situational awareness to a penetration tester during the reconnaissance phase. It gathers information about the local system, users, and domain information. It does not use any 'net', 'ipconfig', 'whoami', 'netstat', or other system commands to help avoid detection.

     Description
    -----------
    This command will run a number of checks on the local system including the retrieval of local system information (netstat, common security products, scheduled tasks, local admins group, LAPS, etc), and domain information (Domain Admins group, DC's, password policy).

    .Example

    C:\PS> Invoke-HostRecon

    #>

    #Hostname

    Write-Output "[*] Hostname"
    $Computer = $env:COMPUTERNAME
    $Computer
    Write-Output "`n"

    #IP Information

    Write-Output "[*] IP Address Info"
    $ipinfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True'| Select-Object IPAddress,Description | Format-Table -Wrap | Out-String
    $ipinfo
    Write-Output "`n"

    #Current user and domain

    Write-Output "[*] Current Domain and Username"

    $currentuser = $env:USERNAME
    Write-Output "Domain = $env:USERDOMAIN"
    Write-Output "Current User = $env:USERNAME"
    Write-Output "`n"

    #All local users

    Write-Output "[*] Local Users of this system"
    $locals = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" | Select-Object Name 
    $locals
    Write-Output "`n"

    #Local Admins group

    Write-Output "[*] Local Admins of this system"
    $Admins = Get-WmiObject win32_groupuser | Where-Object { $_.GroupComponent -match 'administrators' -and ($_.GroupComponent -match "Domain=`"$env:COMPUTERNAME`"")} | ForEach-Object {[wmi]$_.PartComponent } | Select-Object Caption,SID | format-table -Wrap | Out-String
    $Admins
    Write-Output "`n"

    #Netstat Information
    #Some code here borrowed from: http://techibee.com/powershell/query-list-of-listening-ports-in-windows-using-powershell/2344
        Write-Output "[*] Active Network Connections"
        $TCPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()            
        $Connections = $TCPProperties.GetActiveTcpConnections()            
        $objarray = @()
        foreach($Connection in $Connections) {            
            if($Connection.LocalEndPoint.AddressFamily -eq "InterNetwork" ) { $IPType = "IPv4" } else { $IPType = "IPv6" }            
            $OutputObj = New-Object -TypeName PSobject            
            $OutputObj | Add-Member -MemberType NoteProperty -Name "LocalAddress" -Value $Connection.LocalEndPoint.Address            
            $OutputObj | Add-Member -MemberType NoteProperty -Name "LocalPort" -Value $Connection.LocalEndPoint.Port            
            $OutputObj | Add-Member -MemberType NoteProperty -Name "RemoteAddress" -Value $Connection.RemoteEndPoint.Address            
            $OutputObj | Add-Member -MemberType NoteProperty -Name "RemotePort" -Value $Connection.RemoteEndPoint.Port            
            $OutputObj | Add-Member -MemberType NoteProperty -Name "State" -Value $Connection.State            
            $OutputObj | Add-Member -MemberType NoteProperty -Name "IPV4Or6" -Value $IPType            
            $objarray += $OutputObj
            }
            $activeconnections = $objarray | Format-Table -Wrap | Out-String
            $activeconnections

       Write-Output "[*] Active TCP Listeners"            
        $ListenConnections = $TCPProperties.GetActiveTcpListeners()            
        $objarraylisten = @()
            foreach($Connection in $ListenConnections) {            
            if($Connection.address.AddressFamily -eq "InterNetwork" ) { $IPType = "IPv4" } else { $IPType = "IPv6" }                 
            $OutputObjListen = New-Object -TypeName PSobject            
            $OutputObjListen | Add-Member -MemberType NoteProperty -Name "LocalAddress" -Value $connection.Address            
            $OutputObjListen | Add-Member -MemberType NoteProperty -Name "ListeningPort" -Value $Connection.Port            
            $OutputObjListen | Add-Member -MemberType NoteProperty -Name "IPV4Or6" -Value $IPType            
            $objarraylisten += $OutputObjListen }
            $listeners = $objarraylisten | Format-Table -Wrap | Out-String
            $listeners
        
    Write-Output "`n"

    #DNS Cache Information

    Write-Output "[*] DNS Cache"

    try{
    $dnscache = Get-WmiObject -query "Select * from MSFT_DNSClientCache" -Namespace "root\standardcimv2" -ErrorAction stop | Select-Object Entry,Name,Data | Format-Table -Wrap | Out-String
    $dnscache
    }
    catch
        {
        Write-Output "There was an error retrieving the DNS cache."
        }
    Write-Output "`n"

    #Shares

    Write-Output "[*] Share listing"
    $shares = @()
    $shares = Get-WmiObject -Class Win32_Share | Format-Table -Wrap | Out-String
    $shares
    Write-Output "`n"

    #Scheduled Tasks

    Write-Output "[*] List of scheduled tasks"
    $schedule = new-object -com("Schedule.Service")
    $schedule.connect() 
    $tasks = $schedule.getfolder("\").gettasks(0) | Select-Object Name | Format-Table -Wrap | Out-String
    If ($tasks.count -eq 0)
        {
        Write-Output "[*] Task scheduler appears to be empty"
        }
    If ($tasks.count -ne 0)
        {
        $tasks
        }
    Write-Output "`n"

    #Proxy information

    Write-Output "[*] Proxy Info"
    $proxyenabled = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyEnable
    $proxyserver = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyServer

    If ($proxyenabled -eq 1)
        {
            Write-Output "A system proxy appears to be enabled."
            Write-Output "System proxy located at: $proxyserver"
        }
    Elseif($proxyenabled -eq 0)
        {
            Write-Output "There does not appear to be a system proxy enabled."
        }
    Write-Output "`n"

    #Getting AntiVirus Information


    Write-Output "[*] Checking if AV is installed"
    try { $AV = Get-WmiObject -Namespace "root\SecurityCenter2" -Query "SELECT * FROM AntiVirusProduct" -ErrorAction stop } catch [exception] {"No namespace root\SecurityCenter2 found"}

    If ($AV -ne "")
        {
            Write-Output "The following AntiVirus product appears to be installed:" $AV.displayName
        }
    If ($AV -eq "")
        {
            Write-Output "No AV detected."
        }
    Write-Output "`n"

    #Getting Local Firewall Status

    Write-Output "[*] Checking local firewall status."
    $HKLM = 2147483650
    $reg = get-wmiobject -list -namespace root\default -computer $computer | where-object { $_.name -eq "StdRegProv" }
    $firewallEnabled = $reg.GetDwordValue($HKLM, "System\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile","EnableFirewall")
    $fwenabled = [bool]($firewallEnabled.uValue)

    If($fwenabled -eq $true)
        {
            Write-Output "The local firewall appears to be enabled."
        }
    If($fwenabled -ne $true)
        {
            Write-Output "The local firewall appears to be disabled."
        }
    Write-Output "`n"

    #Checking for Local Admin Password Solution (LAPS)

    Write-Output "[*] Checking for Local Admin Password Solution (LAPS)"
    try
        {
        $lapsfile = Get-ChildItem "$env:ProgramFiles\LAPS\CSE\Admpwd.dll" -ErrorAction Stop
        if ($lapsfile)
            {
            Write-Output "The LAPS DLL (Admpwd.dll) was found. Local Admin password randomization may be in use."
            }
        }
    catch
        {
        Write-Output "The LAPS DLL was not found."
        }
    Write-Output "`n"

    #Process Information

    Write-Output "[*] Running Processes"

    $processes = Get-Process | Select-Object ProcessName,Id,Description,Path 
    $processout = $processes | Format-Table -Wrap | Out-String
    $processout
    Write-Output "`n"

    #Checking for common security products

    Write-Output "[*] Checking for Sysinternals Sysmon"
    try
        {
        $sysmondrv = Get-ChildItem "$env:SystemRoot\sysmondrv.sys" -ErrorAction Stop
        if ($sysmondrv)
            {
            Write-Output "The Sysmon driver $($sysmondrv.VersionInfo.FileVersion) (sysmondrv.sys) was found. System activity may be monitored."
            }
        }
    catch
        {
        Write-Output "The Sysmon driver was not found."
        }
    Write-Output "`n"

    Write-Output "[*] Checking for common security product processes"
    $processnames = $processes | Select-Object ProcessName
    Foreach ($ps in $processnames)
            {
            #AV
            if ($ps.ProcessName -like "*mcshield*")
                {
                Write-Output ("Possible McAfee AV process " + $ps.ProcessName + " is running.")
                }
            if (($ps.ProcessName -like "*windefend*") -or ($ps.ProcessName -like "*MSASCui*") -or ($ps.ProcessName -like "*msmpeng*") -or ($ps.ProcessName -like "*msmpsvc*"))
                {
                Write-Output ("Possible Windows Defender AV process " + $ps.ProcessName + " is running.")
                }
            if ($ps.ProcessName -like "*WRSA*")
                {
                Write-Output ("Possible WebRoot AV process " + $ps.ProcessName + " is running.")
                }
            if ($ps.ProcessName -like "*savservice*")
                {
                Write-Output ("Possible Sophos AV process " + $ps.ProcessName + " is running.")
                }
            if (($ps.ProcessName -like "*TMCCSF*") -or ($ps.ProcessName -like "*TmListen*") -or ($ps.ProcessName -like "*NTRtScan*"))
                {
                Write-Output ("Possible Trend Micro AV process " + $ps.ProcessName + " is running.")
                }
            if (($ps.ProcessName -like "*symantec antivirus*") -or ($ps.ProcessName -like "*SymCorpUI*") -or ($ps.ProcessName -like "*ccSvcHst*") -or ($ps.ProcessName -like "*SMC*")  -or ($ps.ProcessName -like "*Rtvscan*"))
                {
                Write-Output ("Possible Symantec AV process " + $ps.ProcessName + " is running.")
                }
            if ($ps.ProcessName -like "*mbae*")
                {
                Write-Output ("Possible MalwareBytes Anti-Exploit process " + $ps.ProcessName + " is running.")
                }
            #if ($ps.ProcessName -like "*mbam*")
               # {
               # Write-Output ("Possible MalwareBytes Anti-Malware process " + $ps.ProcessName + " is running.")
               # }
            #AppWhitelisting
            if ($ps.ProcessName -like "*Parity*")
                {
                Write-Output ("Possible Bit9 application whitelisting process " + $ps.ProcessName + " is running.")
                }
            #Behavioral Analysis
            if ($ps.ProcessName -like "*cb*")
                {
                Write-Output ("Possible Carbon Black behavioral analysis process " + $ps.ProcessName + " is running.")
                }
            if ($ps.ProcessName -like "*bds-vision*")
                {
                Write-Output ("Possible BDS Vision behavioral analysis process " + $ps.ProcessName + " is running.")
                } 
            if ($ps.ProcessName -like "*Triumfant*")
                {
                Write-Output ("Possible Triumfant behavioral analysis process " + $ps.ProcessName + " is running.")
                }
            if ($ps.ProcessName -like "CSFalcon")
                {
                Write-Output ("Possible CrowdStrike Falcon EDR process " + $ps.ProcessName + " is running.")
                }
            #Intrusion Detection
            if ($ps.ProcessName -like "*ossec*")
                {
                Write-Output ("Possible OSSEC intrusion detection process " + $ps.ProcessName + " is running.")
                } 
            #Firewall
            if ($ps.ProcessName -like "*TmPfw*")
                {
                Write-Output ("Possible Trend Micro firewall process " + $ps.ProcessName + " is running.")
                } 
            #DLP
            if (($ps.ProcessName -like "dgagent") -or ($ps.ProcessName -like "DgService") -or ($ps.ProcessName -like "DgScan"))
                {
                Write-Output ("Possible Verdasys Digital Guardian DLP process " + $ps.ProcessName + " is running.")
                }   
            if ($ps.ProcessName -like "kvoop")
                {
                Write-Output ("Possible Unknown DLP process " + $ps.ProcessName + " is running.")
                }                       
            }
    Write-Output "`n"

    #Domain Password Policy

    $domain = "$env:USERDOMAIN"
    Write-Output "[*] Domain Password Policy"
            Try 
            {
                $DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("domain",$domain)
                $DomainObject =[System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
                $CurrentDomain = [ADSI]"WinNT://$env:USERDOMAIN"
                $Name = @{Name="DomainName";Expression={$_.Name}}
	            $MinPassLen = @{Name="Minimum Password Length";Expression={$_.MinPasswordLength}}
                $MinPassAge = @{Name="Minimum Password Age (Days)";Expression={$_.MinPasswordAge.value/86400}}
	            $MaxPassAge = @{Name="Maximum Password Age (Days)";Expression={$_.MaxPasswordAge.value/86400}}
	            $PassHistory = @{Name="Enforce Password History (Passwords remembered)";Expression={$_.PasswordHistoryLength}}
	            $AcctLockoutThreshold = @{Name="Account Lockout Threshold";Expression={$_.MaxBadPasswordsAllowed}}
	            $AcctLockoutDuration =  @{Name="Account Lockout Duration (Minutes)";Expression={if ($_.AutoUnlockInterval.value -eq -1) {'Account is locked out until administrator unlocks it.'} else {$_.AutoUnlockInterval.value/60}}}
	            $ResetAcctLockoutCounter = @{Name="Observation Window";Expression={$_.LockoutObservationInterval.value/60}}
	            $CurrentDomain | Select-Object $Name,$MinPassLen,$MinPassAge,$MaxPassAge,$PassHistory,$AcctLockoutThreshold,$AcctLockoutDuration,$ResetAcctLockoutCounter | format-list | Out-String

            }
            catch 
            {
                Write-Output "Error connecting to the domain while retrieving password policy."    

            }
    Write-Output "`n"

    #Domain Controllers

    Write-Output "[*] Domain Controllers"
            Try 
            {
                $DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("domain",$domain)
                $DomainObject =[System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
                $DCS = $DomainObject.DomainControllers
                foreach ($dc in $DCS)
                {
                    $dc.Name
                }
            
            }
            catch 
            {
                Write-Output "Error connecting to the domain while retrieving listing of Domain Controllers."    

            }
       Write-Output "`n"
   
    #Domain Admins

    Write-Output "[*] Domain Admins"
            Try 
            {
                $DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("domain",$domain)
                $DomainObject =[System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
            
                $DAgroup = ([adsi]"WinNT://$domain/Domain Admins,group")
                $Members = @($DAgroup.psbase.invoke("Members"))
                [Array]$MemberNames = $Members | ForEach{([ADSI]$_).InvokeGet("Name")}
                $MemberNames
            }
            catch 
            {
                Write-Output "Error connecting to the domain while retrieving Domain Admins group members."    

            }
       Write-Output "`n"

    #ExecutionPolicy

    Write-Output "[*] Get WindowsDefenderStatus"

    $DefStatus = Get-WmiObject -Namespace ROOT\Microsoft\Windows\Defender -Class MSFT_MpComputerStatus | Select-Object IoavProtectionEnabled,RealTimeProtectionEnabled | Format-Table -Wrap | Out-String
    $DefStatus
    Write-Output "`n"

    Write-Output "[*] Get ExecutionPolicy"

    $RegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $TargetName)
    $PSRegKey= $RegKey.OpenSubKey("SOFTWARE\\Microsoft\\Powershell\\1\\ShellIds\\Microsoft.PowerShell")
    $Policy = ($PSRegKey.getvalue("ExecutionPolicy")).tostring()
    $Policy
    Write-Output "`n"

}
