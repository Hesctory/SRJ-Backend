using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

/// <summary>
/// Generates the TUITION debt for the month of <c>asOf</c> for every active enrollment
/// in the active school year. Current-month only (no back-months). Idempotent: a debt
/// is created only when one does not already exist for that enrollment + month, so the
/// daily scheduler tick and the dev time-simulator can both run it repeatedly safely.
/// </summary>
public class GenerateMonthlyTuitionUseCase
{
    private readonly IBillingDataQueries _billing;
    private readonly IEnrollmentDebtRepository _debtRepository;
    private readonly IUnitOfWork _unitOfWork;

    public GenerateMonthlyTuitionUseCase(
        IBillingDataQueries billing,
        IEnrollmentDebtRepository debtRepository,
        IUnitOfWork unitOfWork)
    {
        _billing = billing;
        _debtRepository = debtRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<TuitionGenerationResult> ExecuteAsync(DateOnly asOf, int? createdBy = null)
    {
        var month = (short)asOf.Month;
        var enrollments = await _billing.GetActiveEnrollmentsForBillingAsync(asOf.Year);

        var created = 0;
        var skipped = 0;
        var debts = new List<DDebt>();
        var monthsByYear = new Dictionary<int, IReadOnlyList<SchoolYearMonthInfo>>();

        foreach (var e in enrollments)
        {
            if (!monthsByYear.TryGetValue(e.SchoolYearId, out var months))
            {
                months = await _billing.GetSchoolYearMonthsAsync(e.SchoolYearId);
                monthsByYear[e.SchoolYearId] = months;
            }

            var monthInfo = months.FirstOrDefault(m => m.Month == month);
            if (monthInfo is null) continue; // not an academic month for this year (e.g. Jan/Feb)

            if (await _debtRepository.ChargeExistsAsync(e.EnrollmentId, ChargeTypeCodes.Tuition, month))
            {
                skipped++;
                continue;
            }

            var fees = await _billing.GetFeesAsync(e.SchoolYearId, e.LevelId, e.ShiftId, e.SchoolFeeConceptId);
            if (fees is null || fees.Tuition <= 0)
            {
                skipped++;
                continue;
            }

            debts.Add(DDebt.Create(
                e.StudentId, e.EnrollmentId, e.SchoolYearId,
                ChargeTypeCodes.Tuition, fees.Tuition,
                ChargeTypeCodes.TuitionDescription(month, e.Year),
                monthInfo.DueDate, month, asOf));
            created++;
        }

        if (debts.Count > 0)
        {
            await _unitOfWork.BeginAsync();
            try
            {
                await _debtRepository.AddRangeAsync(debts, createdBy);
                await _unitOfWork.CommitAsync();
            }
            catch
            {
                await _unitOfWork.RollbackAsync();
                throw;
            }
        }

        return new TuitionGenerationResult(month, created, skipped);
    }
}
