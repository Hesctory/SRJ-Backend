using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILanguageRepository
{
    Task<List<LanguageDTO>> GetAllAsync();
}
