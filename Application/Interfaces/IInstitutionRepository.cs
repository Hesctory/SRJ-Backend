using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IInstitutionRepository
{
    Task<bool> ExistsAsync(int id);
    Task<bool> RucExistsAsync(string ruc, int? excludeId = null);
    Task<int> CreateAsync(CreateInstitutionDTO dto);
    Task UpdateAsync(int id, CreateInstitutionDTO dto);
    Task<bool> DeleteAsync(int id);
}
