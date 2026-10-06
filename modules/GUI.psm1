# GUI.psm1 - Pełny interfejs graficzny WPF (XAML) dla narzędzia OpenUnbloat

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Apps.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Privacy.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "UI.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Tweaks.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Maintenance.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Software.psm1") -DisableNameChecking

function Start-UnbloatGUI {
    param([switch]$DryRun)

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    $xamlPath = Join-Path (Split-Path $PSScriptRoot -Parent) "ui\MainWindow.xaml"
    if (-not (Test-Path $xamlPath)) {
        Write-LogError "Nie znaleziono pliku interfejsu XAML: $xamlPath"
        return
    }

    [xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $iconPath = Join-Path (Split-Path $PSScriptRoot -Parent) "ui\app_icon.png"
    if (Test-Path $iconPath) {
        try {
            $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($iconPath, [System.UriKind]::Absolute))
        } catch {}
    }

    # Elementy interfejsu
    $mainTabControl          = $window.FindName("mainTabControl")
    $tabTweaks               = $window.FindName("tabTweaks")
    $tabApps                 = $window.FindName("tabApps")
    $tabSoftware             = $window.FindName("tabSoftware")
    $tabMaintenance          = $window.FindName("tabMaintenance")
    $tabLogs                 = $window.FindName("tabLogs")

    $chkDryRun               = $window.FindName("chkDryRun")
    $btnPresetRecommended    = $window.FindName("btnPresetRecommended")
    $btnPresetGaming         = $window.FindName("btnPresetGaming")
    $btnPresetPrivacy        = $window.FindName("btnPresetPrivacy")
    $btnPresetRevert         = $window.FindName("btnPresetRevert")

    $panelTweaksList         = $window.FindName("panelTweaksList")
    $txtSearchTweaks         = $window.FindName("txtSearchTweaks")
    $btnClearSearchTweaks    = $window.FindName("btnClearSearchTweaks")
    $btnSelectAllTweaks      = $window.FindName("btnSelectAllTweaks")
    $btnUnselectAllTweaks    = $window.FindName("btnUnselectAllTweaks")

    $panelAppsList           = $window.FindName("panelAppsList")
    $txtSearchApps           = $window.FindName("txtSearchApps")
    $btnClearSearchApps      = $window.FindName("btnClearSearchApps")
    $chkOnlyInstalledApps    = $window.FindName("chkOnlyInstalledApps")
    $btnScanApps             = $window.FindName("btnScanApps")
    $btnSelectSafeApps       = $window.FindName("btnSelectSafeApps")
    $btnUnselectApps         = $window.FindName("btnUnselectApps")

    $panelSoftwareList       = $window.FindName("panelSoftwareList")
    $txtSearchSoftware       = $window.FindName("txtSearchSoftware")
    $btnClearSearchSoftware  = $window.FindName("btnClearSearchSoftware")
    $btnSelectRecSoftware    = $window.FindName("btnSelectRecSoftware")
    $btnUnselectSoftware     = $window.FindName("btnUnselectSoftware")

    $btnActionCleanup        = $window.FindName("btnActionCleanup")
    $btnActionResetNetwork   = $window.FindName("btnActionResetNetwork")
    $btnActionUltimatePower  = $window.FindName("btnActionUltimatePower")
    $btnActionRepair         = $window.FindName("btnActionRepair")
    $btnActionResetUpdate    = $window.FindName("btnActionResetUpdate")
    $btnActionRepairWinget   = $window.FindName("btnActionRepairWinget")
    $btnActionBackupRegistry = $window.FindName("btnActionBackupRegistry")
    $btnDnsCloudflare        = $window.FindName("btnDnsCloudflare")
    $btnDnsQuad9             = $window.FindName("btnDnsQuad9")
    $btnDnsDhcp              = $window.FindName("btnDnsDhcp")

    $txtLogConsole           = $window.FindName("txtLogConsole")
    $btnCopyLog              = $window.FindName("btnCopyLog")
    $btnSaveLog              = $window.FindName("btnSaveLog")
    $btnClearLog             = $window.FindName("btnClearLog")

    $lblStatus               = $window.FindName("lblStatus")
    $badgeSelectionCount     = $window.FindName("badgeSelectionCount")
    $lblSelectionCount       = $window.FindName("lblSelectionCount")
    $btnCreateRestorePoint   = $window.FindName("btnCreateRestorePoint")
    $btnApplyAllSelected     = $window.FindName("btnApplyAllSelected")
    $pbProgress              = $window.FindName("pbProgress")

    if ($DryRun) {
        $chkDryRun.IsChecked = $true
    }

    # Funkcja dopisywania do dziennika w oknie
    $logAction = {
        param([string]$message)
        $timestamp = (Get-Date).ToString("HH:mm:ss")
        $line = "[$timestamp] $message`r`n"
        $txtLogConsole.AppendText($line)
        $txtLogConsole.ScrollToEnd()
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    }

    # Obsługa stanu zajętości (Marquee ProgressBar i wskaźnik aktywności w tle)
    $setBusyState = {
        param([bool]$busy, [string]$statusText = "")
        if ($pbProgress) {
            if ($busy) {
                $pbProgress.Visibility = [System.Windows.Visibility]::Visible
                $pbProgress.IsIndeterminate = $true
            } else {
                $pbProgress.IsIndeterminate = $false
                $pbProgress.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
        if ($lblStatus -and -not [string]::IsNullOrEmpty($statusText)) {
            $lblStatus.Text = $statusText
        }
        if ($busy) {
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
        } else {
            [System.Windows.Input.Mouse]::OverrideCursor = $null
        }
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
    }

    # Paleta barw i stylizacja kafelków opcji (Zaznaczony vs Niezaznaczony vs Hover)
    $brushCardNormalBg       = [Windows.Media.BrushConverter]::new().ConvertFromString("#151924")
    $brushCardNormalBorder   = [Windows.Media.BrushConverter]::new().ConvertFromString("#22293A")
    $brushCardHoverBg        = [Windows.Media.BrushConverter]::new().ConvertFromString("#1A2131")
    $brushCardHoverBorder    = [Windows.Media.BrushConverter]::new().ConvertFromString("#334155")
    $brushCardSelectedBg     = [Windows.Media.BrushConverter]::new().ConvertFromString("#16233B")
    $brushCardSelectedBorder = [Windows.Media.BrushConverter]::new().ConvertFromString("#3B82F6")

    $script:tweakCards = @()
    $script:appCards = @()
    $script:softwareCards = @()

    $setCardVisualState = {
        param($card, $checkbox)
        if ($null -eq $card -or $null -eq $checkbox) { return }
        if ($checkbox.IsChecked) {
            $card.Background = $brushCardSelectedBg
            $card.BorderBrush = $brushCardSelectedBorder
        } else {
            $card.Background = $brushCardNormalBg
            $card.BorderBrush = $brushCardNormalBorder
        }
    }

    # Obsługa kliknięcia w dowolny punkt kafelka (Click-to-Select) oraz płynny Hover
    $wireCardClickAndHover = {
        param($card, $checkbox)
        
        # Użycie tunelującego zdarzenia Preview, aby kliknięcie w dowolny tekst, tło lub obramowanie natychmiast przełączało checkbox
        $card.Add_PreviewMouseLeftButtonDown({
            param($sender, $e)
            
            # Sprawdź, czy kliknięcie trafiło bezpośrednio w kontrolkę CheckBox lub jej elementy wewnętrzne
            $curr = $e.OriginalSource
            $isInsideCb = $false
            while ($null -ne $curr) {
                if ($curr -eq $checkbox) {
                    $isInsideCb = $true
                    break
                }
                if ($curr -is [System.Windows.Media.Visual] -or $curr -is [System.Windows.Media.Media3D.Visual3D]) {
                    $curr = [System.Windows.Media.VisualTreeHelper]::GetParent($curr)
                } else {
                    break
                }
            }
            # Jeśli kliknięto w sam checkbox, pozwól mu wykonać natywne przełączenie bez podwójnej inwersji
            if ($isInsideCb) { return }

            # Jeśli kliknięto w kafelek poza checkboxem, przełącz stan checkboxa
            if ($checkbox.IsEnabled) {
                $checkbox.IsChecked = -not $checkbox.IsChecked
                $e.Handled = $true
            }
        })

        # Efekt podświetlenia po najechaniu kursorem
        $card.Add_MouseEnter({
            if (-not $checkbox.IsChecked -and $checkbox.IsEnabled) {
                $card.Background = $brushCardHoverBg
                $card.BorderBrush = $brushCardHoverBorder
            }
        })
        $card.Add_MouseLeave({
            & $setCardVisualState $card $checkbox
        })
    }

    # Dynamiczny licznik zaznaczeń i kontekstowy przycisk akcji
    $updateActionState = {
        $selTweaks = @($script:tweakCheckboxes | Where-Object { $_.IsChecked }).Count
        $selApps = @($script:appCheckboxes | Where-Object { $_.IsChecked }).Count
        $selSoftware = @($script:softwareCheckboxes | Where-Object { $_.IsChecked }).Count
        $totalSelected = $selTweaks + $selApps + $selSoftware

        if ($badgeSelectionCount -and $lblSelectionCount) {
            if ($totalSelected -gt 0) {
                $badgeSelectionCount.Visibility = [System.Windows.Visibility]::Visible
                $lblSelectionCount.Text = "Zaznaczono: $totalSelected"
            } else {
                $badgeSelectionCount.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }

        # Zsynchronizuj wizualny stan podświetlenia wszystkich kafelków
        foreach ($item in ($script:tweakCards + $script:appCards + $script:softwareCards)) {
            & $setCardVisualState $item.Card $item.CheckBox
        }

        $activeTab = $mainTabControl.SelectedIndex
        switch ($activeTab) {
            2 { # Zakładka Instalator WinGet
                $btnApplyAllSelected.Content = "📥 Zainstaluj wybrane programy ($selSoftware)"
                $btnApplyAllSelected.IsEnabled = ($selSoftware -gt 0)
            }
            1 { # Zakładka Aplikacje Bloatware
                $btnApplyAllSelected.Content = "🗑️ Usuń zaznaczone aplikacje ($selApps)"
                $btnApplyAllSelected.IsEnabled = ($selApps -gt 0)
            }
            0 { # Zakładka Optymalizacje & Prywatność
                $btnApplyAllSelected.Content = "⚡ Zastosuj wybrane optymalizacje ($selTweaks)"
                $btnApplyAllSelected.IsEnabled = ($selTweaks -gt 0)
            }
            default { # Konserwacja / Dziennik
                $btnApplyAllSelected.Content = "🚀 Zastosuj wszystkie wybrane zmiany ($totalSelected)"
                $btnApplyAllSelected.IsEnabled = ($totalSelected -gt 0)
            }
        }
    }

    # Zmiana aktywnej zakładki natychmiast aktualizuje kontekstowy napis na przycisku
    $mainTabControl.Add_SelectionChanged({ & $updateActionState })

    # --- FILTRY WYSZUKIWANIA NA ŻYWO DLA KAŻDEJ ZAKŁADKI ---
    $filterTweaks = {
        $filter = if ($txtSearchTweaks) { $txtSearchTweaks.Text.Trim().ToLower() } else { "" }
        if ($btnClearSearchTweaks) {
            $btnClearSearchTweaks.Visibility = if ([string]::IsNullOrEmpty($filter)) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        }
        $currentHeader = $null
        $hasVisibleInGroup = $false
        
        foreach ($child in $panelTweaksList.Children) {
            if ($child -is [System.Windows.Controls.TextBlock]) {
                if ($currentHeader) {
                    $currentHeader.Visibility = if ($hasVisibleInGroup) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
                }
                $currentHeader = $child
                $hasVisibleInGroup = [string]::IsNullOrEmpty($filter)
            } elseif ($child -is [System.Windows.Controls.Border] -and $child.Tag) {
                $t = $child.Tag
                $matches = [string]::IsNullOrEmpty($filter) -or 
                           ($t.Name -and $t.Name.ToLower().Contains($filter)) -or 
                           ($t.Description -and $t.Description.ToLower().Contains($filter))
                $child.Visibility = if ($matches) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
                if ($matches) { $hasVisibleInGroup = $true }
            }
        }
        if ($currentHeader) {
            $currentHeader.Visibility = if ($hasVisibleInGroup) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
    }

    $filterApps = {
        $filter = if ($txtSearchApps) { $txtSearchApps.Text.Trim().ToLower() } else { "" }
        $onlyInstalled = if ($chkOnlyInstalledApps) { [bool]$chkOnlyInstalledApps.IsChecked } else { $false }
        
        if ($btnClearSearchApps) {
            $btnClearSearchApps.Visibility = if ([string]::IsNullOrEmpty($filter)) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        }
        $currentHeader = $null
        $hasVisibleInGroup = $false
        
        foreach ($child in $panelAppsList.Children) {
            if ($child -is [System.Windows.Controls.TextBlock]) {
                if ($currentHeader) {
                    $currentHeader.Visibility = if ($hasVisibleInGroup) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
                }
                $currentHeader = $child
                $hasVisibleInGroup = [string]::IsNullOrEmpty($filter) -and -not $onlyInstalled
            } elseif ($child -is [System.Windows.Controls.Border] -and $child.Tag) {
                $app = $child.Tag
                $matchesFilter = [string]::IsNullOrEmpty($filter) -or 
                                 ($app.DisplayName -and $app.DisplayName.ToLower().Contains($filter)) -or 
                                 ($app.Description -and $app.Description.ToLower().Contains($filter)) -or
                                 ($app.Pattern -and $app.Pattern.ToLower().Contains($filter))
                $matchesInstalled = (-not $onlyInstalled) -or [bool]$app.IsInstalled
                $isVisible = $matchesFilter -and $matchesInstalled
                
                $child.Visibility = if ($isVisible) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
                if ($isVisible) { $hasVisibleInGroup = $true }
            }
        }
        if ($currentHeader) {
            $currentHeader.Visibility = if ($hasVisibleInGroup) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
    }

    $filterSoftware = {
        $filter = if ($txtSearchSoftware) { $txtSearchSoftware.Text.Trim().ToLower() } else { "" }
        if ($btnClearSearchSoftware) {
            $btnClearSearchSoftware.Visibility = if ([string]::IsNullOrEmpty($filter)) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        }
        foreach ($child in $panelSoftwareList.Children) {
            if ($child -is [System.Windows.Controls.Border] -and $child.Tag) {
                $pkg = $child.Tag
                $matches = [string]::IsNullOrEmpty($filter) -or 
                           ($pkg.Name -and $pkg.Name.ToLower().Contains($filter)) -or 
                           ($pkg.Description -and $pkg.Description.ToLower().Contains($filter)) -or
                           ($pkg.Id -and $pkg.Id.ToLower().Contains($filter))
                $child.Visibility = if ($matches) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
        }
    }

    # --- ŁADOWANIE TWEAKÓW I FUNKCJI SYSTEMOWYCH ---
    $script:tweakCheckboxes = @()

    $loadTweaks = {
        $panelTweaksList.Children.Clear()
        $script:tweakCheckboxes = @()
        $script:tweakCards = @()
        $db = Get-TweaksDatabase
        $statusList = Get-SystemTweaksStatus

        $grouped = $statusList | Group-Object Category

        foreach ($grp in $grouped) {
            $catInfo = $db.Categories | Where-Object { $_.id -eq $grp.Name }
            $catTitle = if ($catInfo) { "$($catInfo.icon) $($catInfo.name)" } else { $grp.Name }

            # Nagłówek kategorii
            $catHeader = New-Object Windows.Controls.TextBlock
            $catHeader.Text = $catTitle
            $catHeader.FontSize = 13.5
            $catHeader.FontWeight = [Windows.FontWeights]::SemiBold
            $catHeader.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
            $catHeader.Margin = New-Object Windows.Thickness(2, 12, 0, 8)
            $panelTweaksList.Children.Add($catHeader) | Out-Null

            foreach ($item in $grp.Group) {
                # Karta tweaka
                $card = New-Object Windows.Controls.Border
                $card.Tag = $item
                $card.Background = $brushCardNormalBg
                $card.BorderBrush = $brushCardNormalBorder
                $card.BorderThickness = New-Object Windows.Thickness(1)
                $card.CornerRadius = New-Object Windows.CornerRadius(7)
                $card.Padding = New-Object Windows.Thickness(14, 11, 14, 11)
                $card.Margin = New-Object Windows.Thickness(0, 0, 0, 7)
                $card.Cursor = [Windows.Input.Cursors]::Hand

                $grid = New-Object Windows.Controls.Grid
                $grid.Background = [System.Windows.Media.Brushes]::Transparent
                $col0 = New-Object Windows.Controls.ColumnDefinition
                $col0.Width = [Windows.GridLength]::Auto
                $col1 = New-Object Windows.Controls.ColumnDefinition
                $col1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
                $col2 = New-Object Windows.Controls.ColumnDefinition
                $col2.Width = [Windows.GridLength]::Auto
                $grid.ColumnDefinitions.Add($col0)
                $grid.ColumnDefinitions.Add($col1)
                $grid.ColumnDefinitions.Add($col2)

                # Checkbox
                $cb = New-Object Windows.Controls.CheckBox
                $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
                $cb.Margin = New-Object Windows.Thickness(0, 0, 14, 0)
                $cb.Tag = $item
                $cb.Cursor = [Windows.Input.Cursors]::Hand

                $cb.Add_Checked({
                    & $setCardVisualState $card $cb
                    & $updateActionState
                })
                $cb.Add_Unchecked({
                    & $setCardVisualState $card $cb
                    & $updateActionState
                })

                # Obsługa kliknięcia w dowolne miejsce kafelka
                & $wireCardClickAndHover $card $cb

                [Windows.Controls.Grid]::SetColumn($cb, 0)
                $grid.Children.Add($cb) | Out-Null
                $script:tweakCheckboxes += $cb
                $script:tweakCards += @{ Card = $card; CheckBox = $cb }

                # Opis
                $sp = New-Object Windows.Controls.StackPanel
                $sp.VerticalAlignment = [Windows.VerticalAlignment]::Center
                $titleText = New-Object Windows.Controls.TextBlock
                $titleText.Text = $item.Name
                $titleText.FontWeight = [Windows.FontWeights]::SemiBold
                $titleText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#F8FAFC")
                $sp.Children.Add($titleText) | Out-Null

                $descText = New-Object Windows.Controls.TextBlock
                $descText.Text = $item.Description
                $descText.FontSize = 11.5
                $descText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
                $descText.Margin = New-Object Windows.Thickness(0, 2, 0, 0)
                $sp.Children.Add($descText) | Out-Null
                [Windows.Controls.Grid]::SetColumn($sp, 1)
                $grid.Children.Add($sp) | Out-Null

                # Status Badge
                $badge = New-Object Windows.Controls.Border
                $badge.CornerRadius = New-Object Windows.CornerRadius(5)
                $badge.BorderThickness = New-Object Windows.Thickness(1)
                $badge.Padding = New-Object Windows.Thickness(10, 4, 10, 4)
                $badge.VerticalAlignment = [Windows.VerticalAlignment]::Center

                $badgeText = New-Object Windows.Controls.TextBlock
                $badgeText.FontSize = 11
                $badgeText.FontWeight = [Windows.FontWeights]::SemiBold

                if ($item.IsApplied) {
                    $badge.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#0D2818")
                    $badge.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#164E2D")
                    $badgeText.Text = "WŁĄCZONE"
                    $badgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
                } else {
                    $badge.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#1A202C")
                    $badge.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#2D3748")
                    $badgeText.Text = "NIEAKTYWNE"
                    $badgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
                }
                $badge.Child = $badgeText
                [Windows.Controls.Grid]::SetColumn($badge, 2)
                $grid.Children.Add($badge) | Out-Null

                $card.Child = $grid
                $panelTweaksList.Children.Add($card) | Out-Null
            }
        }

        # Plakietka licznika na nagłówku zakładki
        $appliedCount = @($statusList | Where-Object { $_.IsApplied }).Count
        if ($tabTweaks) {
            $tabTweaks.Header = "  🛡️ Optymalizacje & Prywatność ($appliedCount/$($statusList.Count))  "
        }

        if ($filterTweaks) { & $filterTweaks }
        & $updateActionState
    }

    # --- ŁADOWANIE APLIKACJI BLOATWARE ---
    $script:appCheckboxes = @()

    $loadApps = {
        param([bool]$forceRefresh = $false)
        $panelAppsList.Children.Clear()
        $script:appCheckboxes = @()
        $script:appCards = @()

        # Dynamiczny wskaźnik ładowania
        $loadingNotice = New-Object Windows.Controls.TextBlock
        $loadingNotice.Text = "⏳ Trwa sprawdzanie stanu preinstalowanych aplikacji UWP..."
        $loadingNotice.FontSize = 13
        $loadingNotice.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#60CDFF")
        $loadingNotice.Margin = New-Object Windows.Thickness(0, 10, 0, 10)
        $panelAppsList.Children.Add($loadingNotice) | Out-Null
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

        $catalog = Get-BloatwareCatalogStatus -ForceRefresh:$forceRefresh
        $safeApps = @($catalog | Where-Object { $_.Category -eq "SafeToRemove" })
        $optionalApps = @($catalog | Where-Object { $_.Category -eq "Optional" })
        $panelAppsList.Children.Clear()

        $renderCategory = {
            param([string]$title, [array]$items)
            if ($items.Count -eq 0) { return }

            $header = New-Object Windows.Controls.TextBlock
            $header.Text = $title
            $header.FontSize = 13.5
            $header.FontWeight = [Windows.FontWeights]::SemiBold
            $header.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
            $header.Margin = New-Object Windows.Thickness(2, 12, 0, 8)
            $panelAppsList.Children.Add($header) | Out-Null

            foreach ($app in $items) {
                $card = New-Object Windows.Controls.Border
                $card.Tag = $app
                $card.Background = $brushCardNormalBg
                $card.BorderBrush = $brushCardNormalBorder
                $card.BorderThickness = New-Object Windows.Thickness(1)
                $card.CornerRadius = New-Object Windows.CornerRadius(7)
                $card.Padding = New-Object Windows.Thickness(14, 11, 14, 11)
                $card.Margin = New-Object Windows.Thickness(0, 0, 0, 7)
                $card.Cursor = if ($app.IsInstalled) { [Windows.Input.Cursors]::Hand } else { [Windows.Input.Cursors]::Arrow }

                $grid = New-Object Windows.Controls.Grid
                $grid.Background = [System.Windows.Media.Brushes]::Transparent
                $c0 = New-Object Windows.Controls.ColumnDefinition
                $c0.Width = [Windows.GridLength]::Auto
                $c1 = New-Object Windows.Controls.ColumnDefinition
                $c1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
                $c2 = New-Object Windows.Controls.ColumnDefinition
                $c2.Width = [Windows.GridLength]::Auto
                $grid.ColumnDefinitions.Add($c0)
                $grid.ColumnDefinitions.Add($c1)
                $grid.ColumnDefinitions.Add($c2)

                $cb = New-Object Windows.Controls.CheckBox
                $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
                $cb.Margin = New-Object Windows.Thickness(0, 0, 14, 0)
                $cb.Tag = $app
                $cb.IsEnabled = [bool]$app.IsInstalled
                $cb.Cursor = if ($app.IsInstalled) { [Windows.Input.Cursors]::Hand } else { [Windows.Input.Cursors]::Arrow }

                $cb.Add_Checked({
                    & $setCardVisualState $card $cb
                    & $updateActionState
                })
                $cb.Add_Unchecked({
                    & $setCardVisualState $card $cb
                    & $updateActionState
                })

                # Obsługa kliknięcia w dowolne miejsce kafelka
                & $wireCardClickAndHover $card $cb

                [Windows.Controls.Grid]::SetColumn($cb, 0)
                $grid.Children.Add($cb) | Out-Null
                $script:appCheckboxes += $cb
                $script:appCards += @{ Card = $card; CheckBox = $cb }

                $sp = New-Object Windows.Controls.StackPanel
                $sp.VerticalAlignment = [Windows.VerticalAlignment]::Center
                $titleTxt = New-Object Windows.Controls.TextBlock
                $titleTxt.Text = $app.DisplayName
                $titleTxt.FontWeight = [Windows.FontWeights]::SemiBold
                $titleTxt.Foreground = if ($app.IsInstalled) { [Windows.Media.BrushConverter]::new().ConvertFromString("#F8FAFC") } else { [Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8") }
                $sp.Children.Add($titleTxt) | Out-Null

                $descTxt = New-Object Windows.Controls.TextBlock
                $descTxt.Text = $app.Description
                $descTxt.FontSize = 11.5
                $descTxt.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
                $descTxt.Margin = New-Object Windows.Thickness(0, 2, 0, 0)
                $sp.Children.Add($descTxt) | Out-Null
                [Windows.Controls.Grid]::SetColumn($sp, 1)
                $grid.Children.Add($sp) | Out-Null

                # Status Badge
                $badge = New-Object Windows.Controls.Border
                $badge.CornerRadius = New-Object Windows.CornerRadius(5)
                $badge.BorderThickness = New-Object Windows.Thickness(1)
                $badge.Padding = New-Object Windows.Thickness(10, 4, 10, 4)
                $badge.VerticalAlignment = [Windows.VerticalAlignment]::Center

                $badgeText = New-Object Windows.Controls.TextBlock
                $badgeText.FontSize = 11
                $badgeText.FontWeight = [Windows.FontWeights]::SemiBold

                if ($app.IsInstalled) {
                    $badge.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#2E1217")
                    $badge.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#5C1D26")
                    $badgeText.Text = "ZAINSTALOWANA"
                    $badgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
                } else {
                    $badge.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#0D2818")
                    $badge.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#164E2D")
                    $badgeText.Text = "USUNIĘTA"
                    $badgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
                }
                $badge.Child = $badgeText
                [Windows.Controls.Grid]::SetColumn($badge, 2)
                $grid.Children.Add($badge) | Out-Null

                $card.Child = $grid
                $panelAppsList.Children.Add($card) | Out-Null
            }
        }

        & $renderCategory "Aplikacje sponsorowane (Bezpieczne do usunięcia):" $safeApps
        & $renderCategory "Aplikacje opcjonalne systemu Windows (Wybór użytkownika):" $optionalApps

        # Plakietka licznika zainstalowanych bloatware na nagłówku zakładki
        $instActual = @($catalog | Where-Object { $_.IsInstalled }).Count
        if ($tabApps) {
            $tabApps.Header = "  📦 Aplikacje Bloatware ($instActual/$($catalog.Count))  "
        }

        if ($filterApps) { & $filterApps }
        & $updateActionState
    }

    # --- ŁADOWANIE PROGRAMÓW WINGET ---
    $script:softwareCheckboxes = @()

    $loadSoftware = {
        param([bool]$forceRefresh = $false, [bool]$includeWinGet = $false)
        $panelSoftwareList.Children.Clear()
        $script:softwareCheckboxes = @()
        $script:softwareCards = @()

        $catalog = Get-SoftwareCatalogStatus -ForceRefresh:$forceRefresh -IncludeWinGet:$includeWinGet
        $panelSoftwareList.Children.Clear()

        foreach ($pkg in $catalog) {
            $card = New-Object Windows.Controls.Border
            $card.Tag = $pkg
            $card.Background = $brushCardNormalBg
            $card.BorderBrush = $brushCardNormalBorder
            $card.BorderThickness = New-Object Windows.Thickness(1)
            $card.CornerRadius = New-Object Windows.CornerRadius(7)
            $card.Padding = New-Object Windows.Thickness(14, 11, 14, 11)
            $card.Margin = New-Object Windows.Thickness(0, 0, 0, 7)
            $card.Cursor = if (-not $pkg.IsInstalled) { [Windows.Input.Cursors]::Hand } else { [Windows.Input.Cursors]::Arrow }

            $grid = New-Object Windows.Controls.Grid
            $grid.Background = [System.Windows.Media.Brushes]::Transparent
            $c0 = New-Object Windows.Controls.ColumnDefinition
            $c0.Width = [Windows.GridLength]::Auto
            $c1 = New-Object Windows.Controls.ColumnDefinition
            $c1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
            $c2 = New-Object Windows.Controls.ColumnDefinition
            $c2.Width = [Windows.GridLength]::Auto
            $grid.ColumnDefinitions.Add($c0)
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)

            $cb = New-Object Windows.Controls.CheckBox
            $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $cb.Margin = New-Object Windows.Thickness(0, 0, 14, 0)
            $cb.Tag = $pkg
            $cb.IsEnabled = (-not $pkg.IsInstalled)
            $cb.Cursor = if ($pkg.IsInstalled) { [Windows.Input.Cursors]::Arrow } else { [Windows.Input.Cursors]::Hand }

            $cb.Add_Checked({
                & $setCardVisualState $card $cb
                & $updateActionState
            })
            $cb.Add_Unchecked({
                & $setCardVisualState $card $cb
                & $updateActionState
            })

            # Obsługa kliknięcia w dowolne miejsce kafelka
            & $wireCardClickAndHover $card $cb

            [Windows.Controls.Grid]::SetColumn($cb, 0)
            $grid.Children.Add($cb) | Out-Null
            $script:softwareCheckboxes += $cb
            $script:softwareCards += @{ Card = $card; CheckBox = $cb }

            $sp = New-Object Windows.Controls.StackPanel
            $sp.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $nameTxt = New-Object Windows.Controls.TextBlock
            $nameTxt.Text = $pkg.Name
            $nameTxt.FontWeight = [Windows.FontWeights]::SemiBold
            $nameTxt.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#F8FAFC")
            $sp.Children.Add($nameTxt) | Out-Null

            $descTxt = New-Object Windows.Controls.TextBlock
            $descTxt.Text = $pkg.Description
            $descTxt.FontSize = 11.5
            $descTxt.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
            $descTxt.Margin = New-Object Windows.Thickness(0, 2, 0, 0)
            $sp.Children.Add($descTxt) | Out-Null
            [Windows.Controls.Grid]::SetColumn($sp, 1)
            $grid.Children.Add($sp) | Out-Null

            $badge = New-Object Windows.Controls.Border
            $badge.CornerRadius = New-Object Windows.CornerRadius(5)
            $badge.BorderThickness = New-Object Windows.Thickness(1)
            $badge.Padding = New-Object Windows.Thickness(10, 4, 10, 4)
            $badge.VerticalAlignment = [Windows.VerticalAlignment]::Center

            $badgeText = New-Object Windows.Controls.TextBlock
            $badgeText.FontSize = 11
            $badgeText.FontWeight = [Windows.FontWeights]::SemiBold

            if ($pkg.IsInstalled) {
                $badge.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#0D2818")
                $badge.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#164E2D")
                $badgeText.Text = "ZAINSTALOWANY"
                $badgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
            } else {
                $badge.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#132238")
                $badge.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#1D3B60")
                $badgeText.Text = "DOSTĘPNY"
                $badgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
            }
            $badge.Child = $badgeText
            [Windows.Controls.Grid]::SetColumn($badge, 2)
            $grid.Children.Add($badge) | Out-Null

            $card.Child = $grid
            $panelSoftwareList.Children.Add($card) | Out-Null
        }

        # Plakietka licznika zainstalowanych programów na nagłówku zakładki
        $instSoftware = @($catalog | Where-Object { $_.IsInstalled }).Count
        if ($tabSoftware) {
            $tabSoftware.Header = "  💻 Instalator WinGet ($instSoftware/$($catalog.Count))  "
        }

        if ($filterSoftware) { & $filterSoftware }
        & $updateActionState
    }

    # --- PEŁNA WSTĘPNA INICJALIZACJA WSZYSTKICH ZAKŁADEK PRZY WŁĄCZANIU GUI ---
    # Weryfikacja i generowanie wszystkich zakładek odbywa się w całości przy uruchomieniu programu,
    # dzięki czemu późniejsze przełączanie zakładek przez użytkownika jest natychmiastowe (0 ms).
    $lblStatus.Text = "Inicjalizacja: wczytywanie optymalizacji i prywatności..."
    &$logAction "Uruchamianie OpenUnbloat GUI..."
    &$logAction "Sprawdzanie stanu optymalizacji i ustawień prywatności..."
    & $loadTweaks

    $lblStatus.Text = "Inicjalizacja: skanowanie aplikacji bloatware..."
    &$logAction "Skanowanie zainstalowanych aplikacji sponsorowanych (UWP)..."
    & $loadApps

    $lblStatus.Text = "Inicjalizacja: sprawdzanie programów w rejestrze i WinGet..."
    &$logAction "Skanowanie zainstalowanych programów użytkowych (Rejestr & WinGet)..."
    & $loadSoftware

    $lblStatus.Text = "Gotowy do działania. Wybierz opcje i kliknij przycisk akcji."
    &$logAction "Inicjalizacja zakończona pomyślnie. Wszystkie dane są gotowe."

    # --- OBSŁUGA PRZYCISKÓW PROFILI ---
    $btnPresetRecommended.Add_Click({
        foreach ($cb in $script:tweakCheckboxes) {
            $cb.IsChecked = ($cb.Tag.Presets -contains "Recommended" -and -not $cb.Tag.IsApplied)
        }
        foreach ($cb in $script:appCheckboxes) {
            $cb.IsChecked = ($cb.Tag.IsSafe -and $cb.Tag.IsInstalled)
        }
        & $updateActionState
        $lblStatus.Text = "Zaznaczono profil 'Zalecany'."
        &$logAction "Wybrano profil: Zalecany debloat."
    })

    $btnPresetGaming.Add_Click({
        foreach ($cb in $script:tweakCheckboxes) {
            $cb.IsChecked = ($cb.Tag.Presets -contains "Gaming" -or $cb.Tag.Category -eq "GamingAndPerformance")
        }
        & $updateActionState
        $lblStatus.Text = "Zaznaczono profil 'Gracza' (Gaming)."
        &$logAction "Wybrano profil: Wydajność i Gry."
    })

    if ($btnPresetPrivacy) {
        $btnPresetPrivacy.Add_Click({
            foreach ($cb in $script:tweakCheckboxes) {
                $cb.IsChecked = ($cb.Tag.Presets -contains "Privacy" -or $cb.Tag.Category -in @("AI", "Privacy", "Edge") -and -not $cb.Tag.IsApplied)
            }
            foreach ($cb in $script:appCheckboxes) {
                $cb.IsChecked = ($cb.Tag.IsSafe -and $cb.Tag.IsInstalled)
            }
            & $updateActionState
            $lblStatus.Text = "Zaznaczono profil 'Maksymalna Prywatność'."
            &$logAction "Wybrano profil: Maksymalna Ochrona Prywatności & Blokada AI."
        })
    }

    $btnPresetRevert.Add_Click({
        $result = [Windows.MessageBox]::Show("Czy na pewno chcesz przywrócić wszystkie ustawienia systemowe do domyślnych wartości Windows?", "Potwierdzenie cofnięcia", [Windows.MessageBoxButton]::YesNo, [Windows.MessageBoxImage]::Warning)
        if ($result -eq [Windows.MessageBoxResult]::Yes) {
            &$logAction "Rozpoczynanie przywracania domyślnych ustawień fabrycznych..."
            Revert-AllSystemTweaks -IsDryRun:$chkDryRun.IsChecked
            &$logAction "Przywracanie zakończone!"
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            & $loadTweaks
        }
    })

    $btnSelectAllTweaks.Add_Click({
        foreach ($cb in $script:tweakCheckboxes) { $cb.IsChecked = $true }
        & $updateActionState
    })
    $btnUnselectAllTweaks.Add_Click({
        foreach ($cb in $script:tweakCheckboxes) { $cb.IsChecked = $false }
        & $updateActionState
    })

    $btnScanApps.Add_Click({
        & $setBusyState $true "Skanowanie zainstalowanych pakietów bloatware (UWP)..."
        try {
            &$logAction "Odświeżanie listy zainstalowanych aplikacji..."
            & $loadApps $true
            &$logAction "Lista aplikacji została odświeżona."
        } finally {
            & $setBusyState $false "Skanowanie aplikacji zakończone."
        }
    })
    $btnSelectSafeApps.Add_Click({
        foreach ($cb in $script:appCheckboxes) {
            if ($cb.Tag.IsSafe -and $cb.Tag.IsInstalled) { $cb.IsChecked = $true }
        }
        & $updateActionState
    })
    if ($btnUnselectApps) {
        $btnUnselectApps.Add_Click({
            foreach ($cb in $script:appCheckboxes) { $cb.IsChecked = $false }
            & $updateActionState
        })
    }

    $btnSelectRecSoftware.Add_Click({
        foreach ($cb in $script:softwareCheckboxes) {
            if ($cb.Tag.Recommended -and -not $cb.Tag.IsInstalled) { $cb.IsChecked = $true }
        }
        & $updateActionState
    })
    $btnUnselectSoftware.Add_Click({
        foreach ($cb in $script:softwareCheckboxes) { $cb.IsChecked = $false }
        & $updateActionState
    })

    # Podpięcie filtrów i przycisków czyszczenia (X)
    if ($txtSearchTweaks) {
        $txtSearchTweaks.Add_TextChanged({ & $filterTweaks })
    }
    if ($btnClearSearchTweaks) {
        $btnClearSearchTweaks.Add_Click({
            $txtSearchTweaks.Text = ""
            & $filterTweaks
        })
    }

    if ($txtSearchApps) {
        $txtSearchApps.Add_TextChanged({ & $filterApps })
    }
    if ($btnClearSearchApps) {
        $btnClearSearchApps.Add_Click({
            $txtSearchApps.Text = ""
            & $filterApps
        })
    }
    if ($chkOnlyInstalledApps) {
        $chkOnlyInstalledApps.Add_Checked({ & $filterApps })
        $chkOnlyInstalledApps.Add_Unchecked({ & $filterApps })
    }

    if ($txtSearchSoftware) {
        $txtSearchSoftware.Add_TextChanged({ & $filterSoftware })
    }
    if ($btnClearSearchSoftware) {
        $btnClearSearchSoftware.Add_Click({
            $txtSearchSoftware.Text = ""
            & $filterSoftware
        })
    }

    # Operacje na dzienniku zdarzeń
    if ($btnCopyLog) {
        $btnCopyLog.Add_Click({
            $logText = $txtLogConsole.Text
            if ([string]::IsNullOrWhiteSpace($logText)) {
                [Windows.MessageBox]::Show("Dziennik jest pusty - brak danych do skopiowania.", "Informacja", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                return
            }
            try {
                [System.Windows.Clipboard]::SetText($logText)
                $lblStatus.Text = "Skopiowano zawartość dziennika do schowka."
                &$logAction "Dziennik zdarzeń został skopiowany do schowka systemowego."
            } catch {
                [Windows.MessageBox]::Show("Nie udało się skopiować do schowka: $($_.Exception.Message)", "Błąd", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Error)
            }
        })
    }

    if ($btnSaveLog) {
        $btnSaveLog.Add_Click({
            $logText = $txtLogConsole.Text
            if ([string]::IsNullOrWhiteSpace($logText)) {
                [Windows.MessageBox]::Show("Dziennik jest pusty - brak danych do zapisania.", "Informacja", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                return
            }
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "Pliki dziennika (*.log)|*.log|Pliki tekstowe (*.txt)|*.txt"
            $saveDialog.FileName = "Unbloat-Log-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"
            if ($saveDialog.ShowDialog() -eq $true) {
                try {
                    [System.IO.File]::WriteAllText($saveDialog.FileName, $logText, [System.Text.Encoding]::UTF8)
                    &$logAction "Zapisano dziennik do pliku: $($saveDialog.FileName)"
                    [Windows.MessageBox]::Show("Dziennik został pomyślnie zapisany!", "Sukces", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                } catch {
                    [Windows.MessageBox]::Show("Nie udało się zapisać pliku: $($_.Exception.Message)", "Błąd", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Error)
                }
            }
        })
    }

    $btnClearLog.Add_Click({
        $txtLogConsole.Clear()
    })

    $btnCreateRestorePoint.Add_Click({
        & $setBusyState $true "Tworzenie punktu przywracania systemu Windows..."
        try {
            &$logAction "Tworzenie punktu przywracania systemu..."
            New-SystemRestorePoint -Description "Ręczny punkt OpenUnbloat"
            &$logAction "Operacja tworzenia punktu przywracania zakończona."
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        } finally {
            & $setBusyState $false "Punkt przywracania systemu został pomyślnie utworzony."
        }
    })

    # --- OBSŁUGA KAFELKÓW KONSERWACJI ---
    $btnActionCleanup.Add_Click({
        & $setBusyState $true "Trwa czyszczenie dysku i pamięci podręcznej..."
        try {
            &$logAction "Uruchamianie czyszczenia dysku..."
            Invoke-SystemCleanup -DryRun:$chkDryRun.IsChecked
            &$logAction "Czyszczenie dysku zakończone."
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        } finally {
            & $setBusyState $false "Czyszczenie dysku zakończone."
        }
    })

    $btnActionResetNetwork.Add_Click({
        & $setBusyState $true "Trwa resetowanie stosu sieciowego i DNS..."
        try {
            &$logAction "Uruchamianie resetowania sieci i DNS..."
            Invoke-NetworkReset -DryRun:$chkDryRun.IsChecked
            &$logAction "Resetowanie sieci zakończone."
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        } finally {
            & $setBusyState $false "Resetowanie sieci zakończone."
        }
    })

    $btnActionUltimatePower.Add_Click({
        & $setBusyState $true "Aktywowanie planu zasilania Najwyższa wydajność..."
        try {
            &$logAction "Aktywowanie planu zasilania Najwyższa wydajność..."
            Enable-UltimatePerformancePlan -DryRun:$chkDryRun.IsChecked
            &$logAction "Plan zasilania został aktywowany."
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        } finally {
            & $setBusyState $false "Plan zasilania został aktywowany."
        }
    })

    $btnActionRepair.Add_Click({
        & $setBusyState $true "Trwa diagnostyka i naprawa obrazu Windows (SFC & DISM)..."
        try {
            &$logAction "Rozpoczynanie diagnostyki SFC & DISM (może potrwać kilka minut)..."
            Invoke-SystemRepairScan -DryRun:$chkDryRun.IsChecked
            &$logAction "Skanowanie integralności plików zakończone."
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        } finally {
            & $setBusyState $false "Skanowanie integralności plików zakończone."
        }
    })

    if ($btnActionResetUpdate) {
        $btnActionResetUpdate.Add_Click({
            & $setBusyState $true "Trwa resetowanie pamięci podręcznej Windows Update..."
            try {
                &$logAction "Rozpoczynanie czyszczenia i resetowania pamięci podręcznej Windows Update..."
                Reset-WindowsUpdateCache -DryRun:$chkDryRun.IsChecked
                &$logAction "Czyszczenie pamięci podręcznej Windows Update zakończone."
                try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            } finally {
                & $setBusyState $false "Czyszczenie pamięci podręcznej Windows Update zakończone."
            }
        })
    }

    if ($btnActionRepairWinget) {
        $btnActionRepairWinget.Add_Click({
            & $setBusyState $true "Trwa weryfikacja i naprawa repozytoriów WinGet..."
            try {
                &$logAction "Uruchamianie weryfikacji i naprawy repozytoriów WinGet..."
                Repair-WinGetEnvironment -DryRun:$chkDryRun.IsChecked
                &$logAction "Procedura naprawy WinGet zakończona."
                try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            } finally {
                & $setBusyState $false "Procedura naprawy WinGet zakończona."
            }
        })
    }

    if ($btnActionBackupRegistry) {
        $btnActionBackupRegistry.Add_Click({
            & $setBusyState $true "Trwa eksportowanie pełnej kopii zapasowej rejestru..."
            try {
                &$logAction "Eksportowanie pełnej kopii zapasowej rejestru (.reg)..."
                $backupFile = Export-SystemRegistryBackup
                if ($backupFile) {
                    &$logAction "Kopia rejestru została pomyślnie zapisana: $backupFile"
                    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
                    [Windows.MessageBox]::Show("Kopia zapasowa kluczy rejestru została pomyślnie utworzona na Twoim Pulpicie:`n$backupFile", "Kopia Rejestru", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                }
            } finally {
                & $setBusyState $false "Eksport kopii rejestru zakończony."
            }
        })
    }

    if ($btnDnsCloudflare) {
        $btnDnsCloudflare.Add_Click({
            & $setBusyState $true "Ustawianie bezpiecznego Cloudflare DNS (1.1.1.1)..."
            try {
                &$logAction "Konfigurowanie Cloudflare DNS (1.1.1.1 / 1.0.0.1)..."
                Set-NetworkDNSProvider -Provider "Cloudflare" -DryRun:$chkDryRun.IsChecked
                &$logAction "Cloudflare DNS został pomyślnie skonfigurowany."
                try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            } finally {
                & $setBusyState $false "Cloudflare DNS skonfigurowany."
            }
        })
    }

    if ($btnDnsQuad9) {
        $btnDnsQuad9.Add_Click({
            & $setBusyState $true "Ustawianie filtrującego Quad9 DNS (9.9.9.9)..."
            try {
                &$logAction "Konfigurowanie Quad9 DNS (9.9.9.9 / 149.112.112.112)..."
                Set-NetworkDNSProvider -Provider "Quad9" -DryRun:$chkDryRun.IsChecked
                &$logAction "Quad9 DNS został pomyślnie skonfigurowany."
                try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            } finally {
                & $setBusyState $false "Quad9 DNS skonfigurowany."
            }
        })
    }

    if ($btnDnsDhcp) {
        $btnDnsDhcp.Add_Click({
            & $setBusyState $true "Przywracanie domyślnego serwera DNS (DHCP)..."
            try {
                &$logAction "Przywracanie automatycznego DNS (DHCP)..."
                Set-NetworkDNSProvider -Provider "DHCP" -DryRun:$chkDryRun.IsChecked
                &$logAction "Automatyczny DNS (DHCP) został pomyślnie przywrócony."
                try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            } finally {
                & $setBusyState $false "Domyślny DNS (DHCP) przywrócony."
            }
        })
    }

    # --- KONTEKSTOWY PRZYCISK GŁÓWNY: ZASTOSUJ WYBRANE ZMIANY ---
    $btnApplyAllSelected.Add_Click({
        $activeTab = $mainTabControl.SelectedIndex
        $isDry = [bool]$chkDryRun.IsChecked

        $selectedTweaks = @($script:tweakCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag.RawTweak })
        $selectedApps = @($script:appCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
        $selectedSoftware = @($script:softwareCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })

        $doTweaks = $false
        $doApps = $false
        $doSoftware = $false

        switch ($activeTab) {
            0 { # Optymalizacje & Prywatność
                if ($selectedTweaks.Count -eq 0) {
                    [Windows.MessageBox]::Show("Nie wybrano żadnych optymalizacji do zastosowania.", "Brak wyboru", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                    return
                }
                $doTweaks = $true
            }
            1 { # Aplikacje Bloatware
                if ($selectedApps.Count -eq 0) {
                    [Windows.MessageBox]::Show("Nie wybrano żadnych aplikacji bloatware do usunięcia.", "Brak wyboru", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                    return
                }
                $doApps = $true
            }
            2 { # Instalator WinGet
                if ($selectedSoftware.Count -eq 0) {
                    [Windows.MessageBox]::Show("Nie wybrano żadnych programów do zainstalowania.", "Brak wyboru", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                    return
                }
                $doSoftware = $true
            }
            default { # Konserwacja / Dziennik
                $totalCount = $selectedTweaks.Count + $selectedApps.Count + $selectedSoftware.Count
                if ($totalCount -eq 0) {
                    [Windows.MessageBox]::Show("Nie zaznaczono żadnych akcji do wykonania.", "Brak wyboru", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
                    return
                }
                $doTweaks = ($selectedTweaks.Count -gt 0)
                $doApps = ($selectedApps.Count -gt 0)
                $doSoftware = ($selectedSoftware.Count -gt 0)
            }
        }

        $btnApplyAllSelected.IsEnabled = $false
        & $setBusyState $true "Trwa wykonywanie zaplanowanych zmian..."
        
        try {
            &$logAction "=========================================================="
            &$logAction "ROZPOCZYNAM ZASTOSOWANIE ZMIAN"
            if ($isDry) { &$logAction "[TRYB SYMULACJI (DRY-RUN) - Brak zmian na dysku]" }

            # 1. Punkt przywracania (jeśli modyfikujemy konfigurację systemu)
            if (-not $isDry -and ($doTweaks -or $doApps)) {
                &$logAction "Krok 1: Tworzenie punktu przywracania systemu przed zmianami..."
                New-SystemRestorePoint -Description "Przed zastosowaniem zmian OpenUnbloat"
            }

            # 2. Usuwanie aplikacji UWP
            if ($doApps -and $selectedApps.Count -gt 0) {
                &$logAction "Krok 2: Usuwanie zaznaczonych $($selectedApps.Count) aplikacji bloatware..."
                Remove-BloatwareList -Items $selectedApps -DryRun:$isDry
                & $loadApps $true
            }

            # 3. Optymalizacje Tweaks
            if ($doTweaks -and $selectedTweaks.Count -gt 0) {
                &$logAction "Krok 3: Aplikowanie $($selectedTweaks.Count) wybranych optymalizacji..."
                foreach ($tw in $selectedTweaks) {
                    Invoke-TweakAction -Tweak $tw -Mode "Apply" -DryRun:$isDry
                }
                if (-not $isDry) {
                    Restart-ExplorerProcess
                }
                & $loadTweaks
            }

            # 4. Instalacja programów WinGet
            if ($doSoftware -and $selectedSoftware.Count -gt 0) {
                &$logAction "Krok 4: Instalacja $($selectedSoftware.Count) wybranych programów przez WinGet..."
                Install-SoftwareList -Packages $selectedSoftware -DryRun:$isDry
                & $loadSoftware $true
            }

            &$logAction "WSZYSTKIE WYBRANE ZMIANY ZOSTAŁY ZASTOSOWANE POMYŚLNIE!"
            &$logAction "=========================================================="

            # Dźwięk powiadomienia o zakończeniu
            try {
                [System.Media.SystemSounds]::Asterisk.Play()
            } catch {}

            [Windows.MessageBox]::Show("Wszystkie operacje zostały zakończone pomyślnie!", "Sukces", [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
        }
        finally {
            & $setBusyState $false "Zakończono pomyślnie."
            & $updateActionState
        }
    })

    # Skróty klawiszowe (Ctrl+F, Esc, F5)
    $window.Add_KeyDown({
        param($sender, $e)
        
        # Ctrl+F: Przejście do wyszukiwarki w bieżącej zakładce
        if ($e.Key -eq [System.Windows.Input.Key]::F -and [System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
            switch ($mainTabControl.SelectedIndex) {
                0 { if ($txtSearchTweaks) { $txtSearchTweaks.Focus() | Out-Null; $txtSearchTweaks.SelectAll() } }
                1 { if ($txtSearchApps) { $txtSearchApps.Focus() | Out-Null; $txtSearchApps.SelectAll() } }
                2 { if ($txtSearchSoftware) { $txtSearchSoftware.Focus() | Out-Null; $txtSearchSoftware.SelectAll() } }
            }
            $e.Handled = $true
        }
        
        # Esc: Wyczyszczenie aktywnego wyszukiwania
        if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            switch ($mainTabControl.SelectedIndex) {
                0 { if ($txtSearchTweaks -and -not [string]::IsNullOrEmpty($txtSearchTweaks.Text)) { $txtSearchTweaks.Text = ""; & $filterTweaks; $e.Handled = $true } }
                1 { if ($txtSearchApps -and -not [string]::IsNullOrEmpty($txtSearchApps.Text)) { $txtSearchApps.Text = ""; & $filterApps; $e.Handled = $true } }
                2 { if ($txtSearchSoftware -and -not [string]::IsNullOrEmpty($txtSearchSoftware.Text)) { $txtSearchSoftware.Text = ""; & $filterSoftware; $e.Handled = $true } }
            }
        }
        
        # F5: Odświeżenie danych aktywnej zakładki
        if ($e.Key -eq [System.Windows.Input.Key]::F5) {
            switch ($mainTabControl.SelectedIndex) {
                0 { & $loadTweaks }
                1 { & $loadApps $true }
                2 { & $loadSoftware $true }
            }
            $e.Handled = $true
        }
    })

    # Sygnał gotowości do zamknięcia ekranu powitalnego (Splash Screen) w Unbloat.exe
    $window.Add_ContentRendered({
        try {
            $window.Activate() | Out-Null
            $window.Topmost = $true
            $window.Topmost = $false
            $readyEvent = [System.Threading.EventWaitHandle]::OpenExisting("OpenUnbloat_ReadySignal")
            [void]$readyEvent.Set()
            $readyEvent.Dispose()
        } catch {}
    })

    # Otwórz okno
    $window.ShowDialog() | Out-Null
}

Export-ModuleMember -Function Start-UnbloatGUI
