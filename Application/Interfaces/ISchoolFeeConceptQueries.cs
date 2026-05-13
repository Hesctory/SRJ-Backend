using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ISchoolFeeConceptQueries
{
    Task<(List<SchoolFeeConceptDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<SchoolFeeConceptDTO?> GetByIdAsync(int id);
}
