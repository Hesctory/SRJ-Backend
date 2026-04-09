using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetLanguagesUseCase
{
    private readonly ILanguageRepository _languageRepository;

    public GetLanguagesUseCase(ILanguageRepository languageRepository)
    {
        _languageRepository = languageRepository;
    }

    public async Task<List<LanguageDTO>> ExecuteAsync()
    {
        return await _languageRepository.GetAllAsync();
    }
}
