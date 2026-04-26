namespace SRJBackend.Application.Interfaces;

public interface IEducationalPersonRepository
{
    Task<bool> ExistsByPersonIdAsync(int personId);
    Task CreateAsync(int personId, int nativeLanguageId, int? ethnicSelfIdentificationId);
    Task UpdateAsync(int personId, int nativeLanguageId, int? ethnicSelfIdentificationId);
    Task AddSecondLanguagesAsync(int personId, List<int> languageIds);
    Task DeleteSecondLanguagesByEducationalPersonIdAsync(int educationalPersonId);
    Task<bool> TryDeleteAsync(int id);
}
