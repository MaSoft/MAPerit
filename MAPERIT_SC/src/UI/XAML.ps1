#region ============================================================
# MaPeriT.SC - VENTANA PRINCIPAL (shell fijo en XAML)
# El contenido de cada paso del asistente se construye por codigo
# (Wizard.ps1) y se inyecta en ContentHost - mismo patron mixto que
# usa MaPeriT.TN (shell XAML + contenido dinamico por codigo).
# ============================================================

function Get-SCMainWindowXAML {
    $c = $Script:Colors
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$($Script:SC_FullTitle)"
        Width="960" Height="680" MinWidth="860" MinHeight="560"
        WindowStartupLocation="CenterScreen"
        Background="$($c.BgPrimary)"
        FontFamily="Segoe UI">
  <Window.Resources>
    <Style x:Key="SCBtn" TargetType="Button">
      <Setter Property="Padding" Value="18,9"/>
      <Setter Property="Background" Value="$($c.BgCard)"/>
      <Setter Property="Foreground" Value="$($c.Text)"/>
      <Setter Property="BorderBrush" Value="$($c.Border)"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="$($c.BgPanel)"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SCBtnPrimary" TargetType="Button" BasedOn="{StaticResource SCBtn}">
      <Setter Property="Background" Value="$($c.Accent)"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="$($c.AccentHover)"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="$($c.Text)"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,4"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="BorderBrush" Value="$($c.Border)"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="$($c.Text)"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Cabecera -->
    <Border Grid.Row="0" Background="$($c.BgHeader)" Padding="28,18">
      <StackPanel>
        <TextBlock Text="MaPeriT.SC" Foreground="White" FontSize="22" FontWeight="Light"/>
        <TextBlock x:Name="StepIndicatorText" Text="Paso 1" Foreground="#93C5FD" FontSize="12" Margin="0,4,0,0"/>
      </StackPanel>
    </Border>

    <!-- Contenido del paso actual -->
    <Border Grid.Row="1" x:Name="ContentHost" Padding="32,24" Background="$($c.BgPrimary)"/>

    <!-- Pie: navegacion -->
    <Border Grid.Row="2" Background="$($c.BgCard)" BorderBrush="$($c.Border)" BorderThickness="0,1,0,0" Padding="28,16">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="StatusText" Text="" Foreground="$($c.TextMuted)" FontSize="12" VerticalAlignment="Center"/>
          <ProgressBar x:Name="WizardProgressBar" Width="220" Height="14" Margin="14,0,0,0" Visibility="Collapsed" Minimum="0" Maximum="100"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Button x:Name="BtnCancel" Content="Cancelar" Style="{StaticResource SCBtn}" Margin="0,0,8,0"/>
          <Button x:Name="BtnBack" Content="&lt; Atras" Style="{StaticResource SCBtn}" Margin="0,0,8,0"/>
          <Button x:Name="BtnNext" Content="Siguiente &gt;" Style="{StaticResource SCBtnPrimary}"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
"@
}

#endregion
