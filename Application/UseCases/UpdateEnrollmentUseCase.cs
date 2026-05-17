using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.UseCases;

public class UpdateEnrollmentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateEnrollmentUseCase(
        IEnrollmentRepository enrollmentRepository,
        IGradeOfferingShiftSectionRepository sectionRepository,
        IUnitOfWork unitOfWork)
    {
        _enrollmentRepository = enrollmentRepository;
        _sectionRepository = sectionRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<EnrollmentDTO> ExecuteAsync(int id, UpdateEnrollmentDTO dto)
    {
        var existing = await _enrollmentRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException("Matrícula no encontrada.");

        var sectionId = await _sectionRepository.FindValidSectionIdAsync(
            existing.SchoolYearId, dto.GradeId, dto.ShiftId, dto.SectionId);

        if (sectionId == null)
            throw new KeyNotFoundException("La sección indicada no existe o no corresponde al año escolar, grado y turno especificados.");

        var placement = new AcademicPlacement(dto.LevelId, dto.GradeId, dto.ShiftId, sectionId.Value);

        await _unitOfWork.BeginAsync();
        try
        {
            var updated = await _enrollmentRepository.UpdateAsync(id, placement, dto.SchoolFeeConceptId, dto.PreviousSchool);
            await _unitOfWork.CommitAsync();
            return EnrollmentMapper.ToDTO(updated);
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }
    }
}
