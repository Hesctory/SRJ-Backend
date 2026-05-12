using System.Text.Json;
using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGradeOfferingShiftSectionRepository
{
    Task<(List<SectionDTO> Items, int Total)> GetSectionsPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null);
    Task<short> GetCountByShiftAsync(int gradeOfferingShiftId);
    Task AddRangeAsync(int gradeOfferingShiftId, short fromNumber, short toNumber);
    Task RemoveAboveAsync(int gradeOfferingShiftId, short threshold);
    Task RemoveAllByShiftAsync(int gradeOfferingShiftId);
}
