param(
    [string]$DocsFolder = "docs"
)

Get-Module -Name sysadmintoolkit | Remove-Module -ErrorAction SilentlyContinue
Import-Module .\SysAdminToolkit.psd1 -Force

if (Get-Command -Module platyPS -ErrorAction SilentlyContinue) {
    Update-MarkdownHelpModule -Path $DocsFolder -Force -RefreshModulePage
} elseif (Get-Command -Module Microsoft.PowerShell.PlatyPS -ErrorAction SilentlyContinue) {
    Measure-PlatyPSMarkdown -Path "./$DocsFolder/*.md" |
        Where-Object Filetype -Match 'CommandHelp' |
        Update-MarkdownCommandHelp -Path { $_.FilePath } -NoBackup
} else {
    Write-Warning "platyPS module not found. Skipping documentation generation."
}
