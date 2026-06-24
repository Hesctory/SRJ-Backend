namespace SRJBackend.Application.DTOs;

/// <summary>The three fee amounts for a (school year, level, shift, concept) tuple.</summary>
public record SchoolFeeAmounts(decimal Registration, decimal Enrollment, decimal Tuition);

/// <summary>An academic month and its tuition due date, from <c>school_year_months</c>.</summary>
public record SchoolYearMonthInfo(short Month, DateOnly DueDate);

/// <summary>Outcome of a monthly tuition generation run, for logging/diagnostics.</summary>
public record TuitionGenerationResult(short Month, int Created, int Skipped);

/// <summary>Minimal projection of an active enrollment needed to generate its charges.</summary>
public record BillingEnrollment(
    int EnrollmentId,
    int StudentId,
    int SchoolYearId,
    int Year,
    int LevelId,
    int ShiftId,
    int SchoolFeeConceptId);
