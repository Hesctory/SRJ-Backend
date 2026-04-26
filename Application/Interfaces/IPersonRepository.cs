using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IPersonRepository
{
    Task<int?> FindByDocumentAsync(int documentTypeId, string documentNumber);
    Task<int> CreateAsync(DPerson person);
    Task UpdateAsync(int personId, DPerson person);
    Task<bool> TryDeleteAsync(int id);
}
