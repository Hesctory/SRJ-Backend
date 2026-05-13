namespace SRJBackend.Application.DTOs;

public record StudentFilter(
    int? SchoolYearId = null,
    string? FullName = null,
    string? Dni = null);
