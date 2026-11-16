#region ============================================================
# MaPeriT.TN - XAML DE LA VENTANA PRINCIPAL
# ============================================================

function Get-TNMainWindowXAML {
    return @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="MaPeriT.TN — Visor Forense"
    Height="820" Width="1320"
    MinHeight="600" MinWidth="900"
    Background="$($Script:Colors.BgPrimary)"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13"
    UseLayoutRounding="True"
    SnapsToDevicePixels="True">

    <Window.Resources>

        <!-- ── Boton base ─────────────────────────────────────────── -->
        <Style x:Key="TNBtn" TargetType="Button">
            <Setter Property="Foreground"        Value="$($Script:Colors.Text)"/>
            <Setter Property="Background"        Value="$($Script:Colors.BgCard)"/>
            <Setter Property="BorderBrush"       Value="$($Script:Colors.Border)"/>
            <Setter Property="BorderThickness"   Value="1"/>
            <Setter Property="Padding"           Value="12,5"/>
            <Setter Property="FontSize"          Value="12"/>
            <Setter Property="Cursor"            Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.Accent)"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.AccentDark)"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Boton primario (azul) -->
        <Style x:Key="TNBtnPrimary" TargetType="Button" BasedOn="{StaticResource TNBtn}">
            <Setter Property="Background"  Value="$($Script:Colors.Accent)"/>
            <Setter Property="BorderBrush" Value="$($Script:Colors.AccentDark)"/>
            <Setter Property="Foreground"  Value="White"/>
        </Style>

        <!-- Boton icono / sin borde -->
        <Style x:Key="TNBtnIcon" TargetType="Button">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.TextMuted)"/>
            <Setter Property="Padding"         Value="4"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.BgSurface)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ── TreeViewItem ────────────────────────────────────────── -->
        <Style TargetType="TreeViewItem">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="Padding"         Value="3,2"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($Script:Colors.BgSurface)"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="$($Script:Colors.SelectionBg)"/>
                    <Setter Property="Foreground" Value="$($Script:Colors.SelectionFg)"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="TreeView">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>

        <!-- ── TabItem ────────────────────────────────────────────── -->
        <Style TargetType="TabItem">
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.TextMuted)"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="12,7"/>
            <Setter Property="Margin"          Value="0,0,1,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="tb"
                                Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}"
                                BorderThickness="0,0,0,2"
                                BorderBrush="Transparent">
                            <ContentPresenter ContentSource="Header"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="tb" Property="Background"  Value="$($Script:Colors.BgCard)"/>
                                <Setter TargetName="tb" Property="BorderBrush" Value="$($Script:Colors.Accent)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="tb" Property="Background" Value="$($Script:Colors.BgCard)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TabControl">
            <Setter Property="Background"      Value="$($Script:Colors.BgPrimary)"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="0"/>
        </Style>

        <!-- ── TextBox ────────────────────────────────────────────── -->
        <Style x:Key="TNTextBox" TargetType="TextBox">
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="CaretBrush"      Value="$($Script:Colors.Text)"/>
            <Setter Property="BorderBrush"     Value="$($Script:Colors.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="7,4"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4">
                            <ScrollViewer x:Name="PART_ContentHost"
                                          Margin="{TemplateBinding Padding}"
                                          VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="$($Script:Colors.Accent)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ── MenuItem (sin columna de icono) ───────────────────── -->
        <Style TargetType="MenuItem">
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="FontSize"        Value="13"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="10,5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="MenuItem">
                        <Grid SnapsToDevicePixels="True">
                            <Border x:Name="bd"
                                    Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    Padding="{TemplateBinding Padding}">
                                <ContentPresenter ContentSource="Header"
                                                  RecognizesAccessKey="True"
                                                  VerticalAlignment="Center"/>
                            </Border>
                            <Popup x:Name="PART_Popup"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                                   Placement="Bottom">
                                <Border Background="$($Script:Colors.BgPanel)"
                                        BorderBrush="$($Script:Colors.Border)"
                                        BorderThickness="1"
                                        SnapsToDevicePixels="True">
                                    <ScrollViewer CanContentScroll="True" MaxHeight="500"
                                                  VerticalScrollBarVisibility="Auto">
                                        <StackPanel IsItemsHost="True"
                                                    KeyboardNavigation.DirectionalNavigation="Cycle"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.SelectionBg)"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="$($Script:Colors.TextDim)"/>
                            </Trigger>
                            <Trigger Property="Role" Value="SubmenuHeader">
                                <Setter TargetName="PART_Popup" Property="Placement" Value="Right"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="Role" Value="TopLevelHeader"/>
                                    <Condition Property="IsSubmenuOpen" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="bd" Property="Background" Value="$($Script:Colors.BgCard)"/>
                                <Setter Property="Foreground" Value="$($Script:Colors.Text)"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ContextMenu">
            <Setter Property="Background"      Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="BorderBrush"     Value="$($Script:Colors.Border)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ContextMenu">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}"
                                SnapsToDevicePixels="True">
                            <ScrollViewer CanContentScroll="True" MaxHeight="600"
                                          VerticalScrollBarVisibility="Auto">
                                <StackPanel IsItemsHost="True"
                                            KeyboardNavigation.DirectionalNavigation="Cycle"/>
                            </ScrollViewer>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Menu">
            <Setter Property="Background"      Value="Transparent"/>
            <Setter Property="Foreground"      Value="$($Script:Colors.Text)"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>

        <Style TargetType="Separator">
            <Setter Property="Background" Value="$($Script:Colors.Border)"/>
            <Setter Property="Margin"     Value="0,3"/>
            <Setter Property="Height"     Value="1"/>
        </Style>

        <!-- ── ScrollBar minimalista ──────────────────────────────── -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="$($Script:Colors.BgPanel)"/>
            <Setter Property="Width"      Value="8"/>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Height" Value="8"/>
                    <Setter Property="Width"  Value="Auto"/>
                </Trigger>
            </Style.Triggers>
        </Style>

    </Window.Resources>

    <DockPanel LastChildFill="True">

        <!-- ══════════════════════ MENU BAR ══════════════════════════ -->
        <Border DockPanel.Dock="Top" Background="$($Script:Colors.BgHeader)"
                BorderBrush="$($Script:Colors.Border)" BorderThickness="0,0,0,1">
            <DockPanel LastChildFill="False">
                <!-- Logo -->
                <StackPanel DockPanel.Dock="Left" Orientation="Horizontal"
                            VerticalAlignment="Center" Margin="14,0,20,0">
                    <TextBlock Text="MaPeriT" FontSize="15" FontWeight="Bold"
                               Foreground="$($Script:Colors.Accent)" VerticalAlignment="Center"/>
                    <TextBlock Text=".TN" FontSize="15" FontWeight="Light"
                               Foreground="$($Script:Colors.TextMuted)" VerticalAlignment="Center"/>
                </StackPanel>

                <!-- Menus -->
                <Menu DockPanel.Dock="Left" VerticalAlignment="Center" Height="34">
                    <MenuItem Header="_Archivo">
                        <MenuItem x:Name="MenuOpenProject" Header="Abrir Proyecto MaPeriT..."/>
                        <MenuItem x:Name="MenuOpenFile"    Header="Abrir Archivo..."/>
                        <Separator/>
                        <MenuItem x:Name="MenuCloseAll"    Header="Cerrar todas las pestanas"/>
                        <Separator/>
                        <MenuItem x:Name="MenuExit"        Header="Salir"/>
                    </MenuItem>
                    <MenuItem Header="_Vista">
                        <MenuItem x:Name="MenuToggleTree"  Header="Panel Explorador" IsCheckable="True" IsChecked="True"/>
                        <Separator/>
                        <MenuItem x:Name="MenuRefresh"     Header="Recargar proyecto"/>
                    </MenuItem>
                    <MenuItem Header="_Analisis">
                        <MenuItem x:Name="MenuIOCScan"   Header="Escanear IOCs en proyecto"/>
                        <MenuItem x:Name="MenuTimeline"  Header="Timeline consolidada"/>
                        <Separator/>
                        <MenuItem x:Name="MenuBookmarks" Header="Marcadores"/>
                        <Separator/>
                        <MenuItem x:Name="MenuGlobalSearchAll" Header="Busqueda global (todos los formatos)"/>
                    </MenuItem>
                    <MenuItem Header="A_yuda">
                        <MenuItem x:Name="MenuAbout" Header="Acerca de MaPeriT.TN"/>
                    </MenuItem>
                </Menu>
            </DockPanel>
        </Border>

        <!-- ══════════════════════ TOOLBAR ═══════════════════════════ -->
        <Border DockPanel.Dock="Top" Background="$($Script:Colors.BgPanel)"
                BorderBrush="$($Script:Colors.Border)" BorderThickness="0,0,0,1"
                Padding="10,6,10,6">
            <DockPanel LastChildFill="False">
                <!-- Izquierda: botones de accion -->
                <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
                    <Button x:Name="BtnOpenProject" Style="{StaticResource TNBtnPrimary}"
                            Height="28" Margin="0,0,6,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#128193;" Margin="0,0,6,0" VerticalAlignment="Center" FontSize="13"/>
                            <TextBlock Text="Abrir Proyecto" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="BtnOpenFile" Style="{StaticResource TNBtn}"
                            Height="28" Margin="0,0,16,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#128196;" Margin="0,0,6,0" VerticalAlignment="Center" FontSize="13"/>
                            <TextBlock Text="Abrir Archivo" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>

                    <!-- Nombre del proyecto activo -->
                    <TextBlock x:Name="TxtProjectLabel"
                               Text="Sin proyecto abierto"
                               Foreground="$($Script:Colors.TextDim)"
                               VerticalAlignment="Center"
                               FontSize="12"/>
                </StackPanel>

                <!-- Derecha: tema + busqueda global -->
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                    <Button x:Name="BtnThemeToggle" Style="{StaticResource TNBtnIcon}"
                            Width="30" Height="28" Margin="0,0,8,0"
                            ToolTip="Cambiar tema claro / oscuro">
                        <TextBlock x:Name="TxtThemeIcon" FontSize="14"
                                   Text="&#9728;" VerticalAlignment="Center"
                                   HorizontalAlignment="Center"/>
                    </Button>
                    <TextBlock Text="Buscar:" Foreground="$($Script:Colors.TextMuted)" FontSize="11"
                               VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <TextBox x:Name="TxtGlobalSearch" Style="{StaticResource TNTextBox}"
                             Width="210" Height="28"/>
                    <Button x:Name="BtnGlobalSearch" Style="{StaticResource TNBtn}"
                            Height="28" Width="30" Padding="0" Margin="4,0,0,0">
                        <TextBlock Text="&#128269;" FontSize="14"/>
                    </Button>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- ══════════════════════ STATUS BAR ════════════════════════ -->
        <Border DockPanel.Dock="Bottom" Background="$($Script:Colors.BgHeader)"
                BorderBrush="$($Script:Colors.Border)" BorderThickness="0,1,0,0"
                Padding="10,3">
            <DockPanel LastChildFill="False">
                <TextBlock x:Name="TxtStatusLeft"  DockPanel.Dock="Left"
                           Text="Listo" Foreground="$($Script:Colors.TextDim)" FontSize="11"
                           VerticalAlignment="Center"/>
                <TextBlock x:Name="TxtStatusRight" DockPanel.Dock="Right"
                           Text="" Foreground="$($Script:Colors.TextDim)" FontSize="11"
                           VerticalAlignment="Center"/>
            </DockPanel>
        </Border>

        <!-- ══════════════════════ MAIN CONTENT ══════════════════════ -->
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition x:Name="LeftCol" Width="270" MinWidth="140" MaxWidth="600"/>
                <ColumnDefinition Width="4"/>
                <ColumnDefinition Width="*" MinWidth="300"/>
            </Grid.ColumnDefinitions>

            <!-- ── PANEL IZQUIERDO: Explorador ─────────────────────── -->
            <Border x:Name="PanelLeft" Grid.Column="0" Background="$($Script:Colors.BgPanel)">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Cabecera panel -->
                    <Border Grid.Row="0" Background="$($Script:Colors.BgHeader)"
                            BorderBrush="$($Script:Colors.Border)" BorderThickness="0,0,0,1"
                            Padding="10,7">
                        <TextBlock Text="EXPLORADOR" Foreground="$($Script:Colors.TextDim)"
                                   FontSize="10" FontWeight="SemiBold"
                                   VerticalAlignment="Center"/>
                    </Border>

                    <!-- Filtro de arbol -->
                    <Border Grid.Row="1" Background="$($Script:Colors.BgPanel)" Padding="6,5">
                        <TextBox x:Name="TxtTreeFilter" Style="{StaticResource TNTextBox}"
                                 Height="26" FontSize="11"
                                 ToolTip="Filtrar archivos en el arbol"/>
                    </Border>

                    <!-- TreeView -->
                    <ScrollViewer Grid.Row="2"
                                  VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Auto"
                                  Background="$($Script:Colors.BgPanel)">
                        <TreeView x:Name="ProjectTree"
                                  Background="Transparent"
                                  BorderThickness="0"
                                  Padding="4,4,4,20"/>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- ── SEPARADOR ──────────────────────────────────────── -->
            <GridSplitter Grid.Column="1" Width="4"
                          HorizontalAlignment="Stretch"
                          Background="$($Script:Colors.BgCard)" Cursor="SizeWE"/>

            <!-- ── PANEL DERECHO: Contenido ───────────────────────── -->
            <Grid Grid.Column="2">

                <!-- TabControl para pestanas abiertas -->
                <TabControl x:Name="TabsMain"
                            Background="$($Script:Colors.BgPrimary)"
                            BorderThickness="0"
                            Padding="0"/>

                <!-- Estado vacio (se oculta cuando hay pestanas) -->
                <Grid x:Name="GridEmptyState" Background="$($Script:Colors.BgPrimary)"
                      Visibility="Visible">
                    <StackPanel HorizontalAlignment="Center"
                                VerticalAlignment="Center">
                        <TextBlock HorizontalAlignment="Center">
                            <Run Text="MaPeriT" FontSize="54" FontWeight="Thin"
                                 Foreground="$($Script:Colors.BgSurface)"/>
                            <Run Text=".TN" FontSize="54" FontWeight="Light"
                                 Foreground="$($Script:Colors.Accent)"/>
                        </TextBlock>
                        <TextBlock Text="Visor Forense del Ecosistema MaPeriT"
                                   FontSize="14" Foreground="$($Script:Colors.BorderLight)"
                                   TextAlignment="Center" Margin="0,4,0,40"/>

                        <StackPanel Orientation="Horizontal"
                                    HorizontalAlignment="Center">
                            <Button x:Name="BtnEmptyProject"
                                    Style="{StaticResource TNBtnPrimary}"
                                    Padding="18,10" Margin="0,0,12,0"
                                    FontSize="13">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#128193;" Margin="0,0,8,0" FontSize="15"/>
                                    <TextBlock Text="Abrir Proyecto MaPeriT"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnEmptyFile"
                                    Style="{StaticResource TNBtn}"
                                    Padding="18,10"
                                    FontSize="13">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#128196;" Margin="0,0,8,0" FontSize="15"/>
                                    <TextBlock Text="Abrir Archivo"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </StackPanel>
                </Grid>

            </Grid>
        </Grid>

    </DockPanel>
</Window>
"@
}

#endregion
