using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class GetChildbirthTypesUseCase
{
    private readonly IChildbirthTypeRepository _childbirthTypeRepository;

    public GetChildbirthTypesUseCase(IChildbirthTypeRepository childbirthTypeRepository)
    {
        _childbirthTypeRepository = childbirthTypeRepository;
    }

    public async Task<List<ChildbirthTypeDTO>> ExecuteAsync()
    {
        return await _childbirthTypeRepository.GetAllAsync();
    }
}
