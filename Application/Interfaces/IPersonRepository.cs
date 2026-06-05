using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IPersonRepository
{
    Task<int?> FindByDocumentAsync(int documentTypeId, string documentNumber);
    Task<int> CreateAsync(DPerson person);
    Task UpdateAsync(int personId, DPerson person);
    Task UpdateDemographicsAsync(int personId, int nativeLanguageId, int? ethnicSelfIdentificationId);
    Task AddSecondLanguagesAsync(int personId, List<int> languageIds);
    Task DeleteSecondLanguagesAsync(int personId);
    Task<bool> TryDeleteAsync(int id);
}
