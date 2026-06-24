using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

/// <summary>Read-only lookups used by the debt-generation use cases.</summary>
public interface IBillingDataQueries
{
    /// <summary>Fee amounts for the pricing tuple, or null if no fee row exists.</summary>
    Task<SchoolFeeAmounts?> GetFeesAsync(int schoolYearId, int levelId, int shiftId, int schoolFeeConceptId);

    /// <summary>The academic months (3–12) and their due dates for a school year.</summary>
    Task<IReadOnlyList<SchoolYearMonthInfo>> GetSchoolYearMonthsAsync(int schoolYearId);

    /// <summary>The calendar year for a school year id.</summary>
    Task<int> GetYearAsync(int schoolYearId);

    /// <summary>
    /// Active enrollments whose school year matches the given calendar year. Pinning to the
    /// current year keeps monthly tuition off next-year pre-registration enrollments (which
    /// can coexist with the current one from August onward).
    /// </summary>
    Task<IReadOnlyList<BillingEnrollment>> GetActiveEnrollmentsForBillingAsync(int year);
}
