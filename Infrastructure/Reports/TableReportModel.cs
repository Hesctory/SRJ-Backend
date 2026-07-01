namespace SRJBackend.Infrastructure.Reports;

/// <summary>A single column in a tabular report.</summary>
/// <param name="Header">Column header text.</param>
/// <param name="WidthCm">Column width in centimeters (used by the PDF renderer).</param>
/// <param name="Numeric">
/// True for numeric columns (e.g. the "#" index). Excel writes these as numbers;
/// everything else is written as text so codes/DNIs keep their leading zeros.
/// </param>
public sealed record TableColumn(string Header, double WidthCm, bool Numeric = false);

/// <summary>
/// Format-neutral model for the three tabular reports (enrolled / birthdays /
/// withdrawn). The exporter fills it in; the PDF and Excel renderers consume it.
/// </summary>
public sealed class TableReportModel
{
    public string SchoolName { get; init; } = "SRJ — Sistema de Gestión Escolar";
    public string Title { get; init; } = "";
    public string ContextLine { get; init; } = "";
    public IReadOnlyList<TableColumn> Columns { get; init; } = Array.Empty<TableColumn>();

    /// <summary>Row cells as strings, aligned to <see cref="Columns"/>.</summary>
    public IReadOnlyList<IReadOnlyList<string>> Rows { get; init; } = Array.Empty<IReadOnlyList<string>>();

    public int Total => Rows.Count;
}
