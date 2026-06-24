using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

/// <summary>
/// Generates the one-off charges raised when an enrollment is created:
/// ADMISSION (only for brand-new students) + ENROLLMENT (always).
/// Runs inside the caller's transaction — it does NOT open its own UnitOfWork.
/// Idempotent and self-skipping: zero-amount fees and already-existing charges are skipped.
/// </summary>
public class GenerateEnrollmentChargesUseCase
{
    private readonly IBillingDataQueries _billing;
    private readonly IEnrollmentDebtRepository _debtRepository;
    private readonly IClock _clock;

    public GenerateEnrollmentChargesUseCase(
        IBillingDataQueries billing,
        IEnrollmentDebtRepository debtRepository,
        IClock clock)
    {
        _billing = billing;
        _debtRepository = debtRepository;
        _clock = clock;
    }

    public async Task ExecuteAsync(DEnrollment enrollment, bool isNew, int? createdBy)
    {
        var fees = await _billing.GetFeesAsync(
            enrollment.SchoolYearId,
            enrollment.Placement.LevelId,
            enrollment.Placement.ShiftId,
            enrollment.SchoolFeeConceptId);

        if (fees is null) return; // no pricing configured → nothing to charge

        var months = await _billing.GetSchoolYearMonthsAsync(enrollment.SchoolYearId);
        var firstMonth = months.FirstOrDefault(m => m.Month == 3);
        if (firstMonth is null) return; // calendar not configured → cannot set due date

        var year = await _billing.GetYearAsync(enrollment.SchoolYearId);
        var asOf = _clock.Today;
        var debts = new List<DDebt>();

        if (isNew && fees.Registration > 0
            && !await _debtRepository.ChargeExistsAsync(enrollment.Id, ChargeTypeCodes.Admission, null))
        {
            debts.Add(DDebt.Create(
                enrollment.StudentId, enrollment.Id, enrollment.SchoolYearId,
                ChargeTypeCodes.Admission, fees.Registration,
                ChargeTypeCodes.AdmissionDescription(year), firstMonth.DueDate, null, asOf));
        }

        if (fees.Enrollment > 0
            && !await _debtRepository.ChargeExistsAsync(enrollment.Id, ChargeTypeCodes.Enrollment, null))
        {
            debts.Add(DDebt.Create(
                enrollment.StudentId, enrollment.Id, enrollment.SchoolYearId,
                ChargeTypeCodes.Enrollment, fees.Enrollment,
                ChargeTypeCodes.EnrollmentDescription(year), firstMonth.DueDate, null, asOf));
        }

        await _debtRepository.AddRangeAsync(debts, createdBy);
    }
}
