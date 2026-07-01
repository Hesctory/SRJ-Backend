namespace SRJBackend.Application.DTOs;

/// <summary>
/// Human-readable labels resolved from the report filter ids, used to build the
/// "filter context line" printed in report headers (e.g. "Año: 2026 · Nivel: Primaria").
/// Any part left null means that filter was not applied.
/// </summary>
public class ReportContextDTO
{
    public string? SchoolYear { get; set; }
    public string? Level { get; set; }
    public string? Grade { get; set; }
    public string? Shift { get; set; }
    public string? Section { get; set; }
}
