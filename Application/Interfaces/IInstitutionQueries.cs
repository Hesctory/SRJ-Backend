using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IInstitutionQueries
{
    Task<(List<InstitutionDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<InstitutionDTO?> GetByIdAsync(int id);
}
