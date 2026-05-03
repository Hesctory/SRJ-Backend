using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IInstitutionRepository
{
    Task<(List<InstitutionDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<InstitutionDTO?> GetByIdAsync(int id);
    Task<bool> ExistsAsync(int id);
    Task<bool> RucExistsAsync(string ruc, int? excludeId = null);
    Task<int> CreateAsync(CreateInstitutionDTO dto);
    Task UpdateAsync(int id, CreateInstitutionDTO dto);
    Task<bool> DeleteAsync(int id);
}
