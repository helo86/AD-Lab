Get-DomainComputer -LDAPFilter '(dnshostname=*)' -Properties dnshostname -UACFilter NOT_TRUSTED_FOR_DELEGATION -Ping | % {
    try {
        $ComputerName = $_.dnshostname
        Get-WmiObject -Class Win32_UserProfile -Filter "NOT SID = 'S-1-5-18' AND NOT SID = 'S-1-5-19' AND NOT SID = 'S-1-5-20'" -ComputerName $_.dnshostname -ErrorAction SilentlyContinue | % {
            if ($_.SID -match 'S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+$') {
                $LocalPath, $Time = '', ''
                if ($_.LastUseTime) { $Time = ([WMI]'').ConvertToDateTime($_.LastUseTime) }
                if ($_.LocalPath) { $LocalPath = $_.LocalPath.Split('\')[-1] }
                New-Object PSObject -Property @{'ComputerName'=$ComputerName ; 'SID'=$_.SID; 'LocalPath'=$LocalPath; 'LastUseTime'=$Time}
            }
        }
    }
    catch {}
} | Export-Csv -NoTypeInformation user_profiles.csv
