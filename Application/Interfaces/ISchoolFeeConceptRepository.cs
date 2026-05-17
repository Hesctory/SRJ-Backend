using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ISchoolFeeConceptRepository
{
    Task<bool> NameExistsAsync(string name, int? excludeId = null);
    Task<int> CreateAsync(CreateSchoolFeeConceptDTO dto);
    Task UpdateAsync(int id, CreateSchoolFeeConceptDTO dto);
    Task<bool> DeleteAsync(int id);
}
