using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateInstitutionUseCase
{
    private readonly IInstitutionRepository _institutionRepository;

    public CreateInstitutionUseCase(IInstitutionRepository institutionRepository)
    {
        _institutionRepository = institutionRepository;
    }

    public async Task<int> ExecuteAsync(CreateInstitutionDTO dto)
    {
        if (await _institutionRepository.RucExistsAsync(dto.Ruc))
            throw new InvalidOperationException("Ya existe una institución registrada con ese RUC.");

        return await _institutionRepository.CreateAsync(dto);
    }
}
