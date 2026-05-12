using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ISchoolFeeConceptRepository
{
    Task<(List<SchoolFeeConceptDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<SchoolFeeConceptDTO?> GetByIdAsync(int id);
    Task<bool> NameExistsAsync(string name, int? excludeId = null);
    Task<int> CreateAsync(CreateSchoolFeeConceptDTO dto);
    Task UpdateAsync(int id, CreateSchoolFeeConceptDTO dto);
    Task<bool> DeleteAsync(int id);
}
