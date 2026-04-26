using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILevelOfEducationRepository
{
    Task<List<LevelOfEducationDTO>> GetAllAsync();
}
