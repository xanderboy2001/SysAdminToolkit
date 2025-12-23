function Show-RDMenu {
    $menuOptions = @(
        'Disable Connections'
        'List Active Users'
    )

    $result = Show-Menu -Title 'Remote Desktop Menu' -Options $menuOptions

    if ($result.Quit) { return }
    if ($result.Back) { Show-ServerMenu }

    switch ($result.Index) {
        0 { <#disable connections#> }
        1 { <#list active users#> }
    }
}