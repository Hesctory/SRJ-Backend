namespace SRJBackend.Application.DTOs;

public record StudentFilter(
    int? SchoolYearId = null,
    string? FullName = null,
    string? Dni = null,
    int? LevelId = null,
    int? GradeId = null,
    int? ShiftId = null,
    int? SectionId = null);
