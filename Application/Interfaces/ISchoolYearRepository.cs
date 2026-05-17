using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface ISchoolYearRepository
{
    Task<bool> ExistsAsync(int id);
    Task<bool> YearExistsAsync(short year, int? excludeId = null);
    Task<DSchoolYear?> FindByIdAsync(int id);
    Task<int> CreateAsync(DSchoolYear schoolYear);
    Task UpdateAsync(DSchoolYear schoolYear);
    Task<bool> DeleteAsync(int id);
}
