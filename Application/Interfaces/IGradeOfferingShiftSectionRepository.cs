namespace SRJBackend.Application.Interfaces;

public interface IGradeOfferingShiftSectionRepository
{
    Task<short> GetCountByShiftAsync(int gradeOfferingShiftId);
    Task AddRangeAsync(int gradeOfferingShiftId, short fromNumber, short toNumber);
    Task RemoveAboveAsync(int gradeOfferingShiftId, short threshold);
    Task RemoveAllByShiftAsync(int gradeOfferingShiftId);
    Task<int?> FindValidSectionIdAsync(int schoolYearId, int gradeId, int shiftId, int sectionId);
}
