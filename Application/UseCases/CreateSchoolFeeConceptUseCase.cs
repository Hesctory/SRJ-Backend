using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class CreateSchoolFeeConceptUseCase
{
    private readonly ISchoolFeeConceptRepository _schoolFeeConceptRepository;

    public CreateSchoolFeeConceptUseCase(ISchoolFeeConceptRepository schoolFeeConceptRepository)
    {
        _schoolFeeConceptRepository = schoolFeeConceptRepository;
    }

    public async Task<int> ExecuteAsync(CreateSchoolFeeConceptDTO dto)
    {
        if (await _schoolFeeConceptRepository.NameExistsAsync(dto.Name))
            throw new InvalidOperationException("Ya existe un concepto de pago con ese nombre.");

        return await _schoolFeeConceptRepository.CreateAsync(dto);
    }
}
