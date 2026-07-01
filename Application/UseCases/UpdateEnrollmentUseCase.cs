using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.UseCases;

public class UpdateEnrollmentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly IEnrollmentQueries _enrollmentQueries;
    private readonly IStudentRepository _studentRepository;
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;
    private readonly IUnitOfWork _unitOfWork;

    public UpdateEnrollmentUseCase(
        IEnrollmentRepository enrollmentRepository,
        IEnrollmentQueries enrollmentQueries,
        IStudentRepository studentRepository,
        IGradeOfferingShiftSectionRepository sectionRepository,
        IUnitOfWork unitOfWork)
    {
        _enrollmentRepository = enrollmentRepository;
        _enrollmentQueries = enrollmentQueries;
        _studentRepository = studentRepository;
        _sectionRepository = sectionRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<EnrollmentDTO> ExecuteAsync(int id, UpdateEnrollmentDTO dto, int? changedBy = null)
    {
        var existing = await _enrollmentRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException("Matrícula no encontrada.");

        if (dto.StateName != null)
            return await HandleStateTransitionAsync(id, existing, dto.StateName, changedBy);

        return await HandlePlacementUpdateAsync(id, existing, dto);
    }

    private async Task<EnrollmentDTO> HandleStateTransitionAsync(int id, DEnrollment existing, string stateName, int? changedBy)
    {
        await _unitOfWork.BeginAsync();
        try
        {
            if (stateName == EnrollmentStateNames.Cancelled && existing.Status != EnrollmentStatus.Cancelled)
            {
                await _enrollmentRepository.CancelAsync(id, changedBy);
                var hasValid = await _enrollmentQueries.HasValidEnrollmentsAsync(existing.StudentId);
                if (!hasValid)
                    await _studentRepository.ArchiveAsync(existing.StudentId);
            }
            else if (stateName == EnrollmentStateNames.Withdrawn && existing.Status == EnrollmentStatus.Active)
            {
                await _enrollmentRepository.WithdrawAsync(id, changedBy);
            }
            else if (stateName == EnrollmentStateNames.Active && existing.Status == EnrollmentStatus.Cancelled)
            {
                await _enrollmentRepository.ReactivateAsync(id, changedBy);
                var isArchived = await _studentRepository.IsArchivedAsync(existing.StudentId);
                if (isArchived)
                    await _studentRepository.UnarchiveAsync(existing.StudentId);
            }
            else if (stateName == EnrollmentStateNames.Active && existing.Status == EnrollmentStatus.Withdrawn)
            {
                await _enrollmentRepository.ReactivateAsync(id, changedBy);
            }

            await _unitOfWork.CommitAsync();
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }

        return EnrollmentMapper.ToDTO(
            await _enrollmentRepository.GetByIdAsync(id) ?? throw new KeyNotFoundException("Matrícula no encontrada."));
    }

    private async Task<EnrollmentDTO> HandlePlacementUpdateAsync(int id, DEnrollment existing, UpdateEnrollmentDTO dto)
    {
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
