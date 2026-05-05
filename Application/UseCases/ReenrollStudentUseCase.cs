using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Application.UseCases;

public class ReenrollStudentUseCase
{
    private readonly IStudentRepository _studentRepository;
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly ISchoolYearRepository _schoolYearRepository;
    private readonly SRJDbContext _context;

    public ReenrollStudentUseCase(
        IStudentRepository studentRepository,
        IEnrollmentRepository enrollmentRepository,
        ISchoolYearRepository schoolYearRepository,
        SRJDbContext context)
    {
        _studentRepository = studentRepository;
        _enrollmentRepository = enrollmentRepository;
        _schoolYearRepository = schoolYearRepository;
        _context = context;
    }

    public async Task<ReenrollResultDTO> ExecuteAsync(int studentId, CreateEnrollmentDTO dto)
    {
        if (!await _studentRepository.ExistsByEducationalPersonIdAsync(studentId))
            throw new DomainException("STUDENT_NOT_FOUND", "El estudiante no existe.");

        var blockedStatuses = new[] { StudentStateNames.Blocked, StudentStateNames.Expelled, StudentStateNames.Withdrawn };
        var hasBlockedStatus = await _context.StudentStatesByYears
            .AnyAsync(s => s.StudentId == studentId
                     && s.SchoolYearId == dto.SchoolYearId
                     && s.Status.Name != null
                     && blockedStatuses.Contains(s.Status.Name.ToLower()));

        if (hasBlockedStatus)
            throw new DomainException("STUDENT_BLOCKED_FOR_YEAR", "El estudiante no puede matricularse en este año escolar.");

        if (!await _schoolYearRepository.IsOpenAsync(dto.SchoolYearId))
            throw new DomainException("YEAR_NOT_OPEN", "El año escolar no está abierto para matrícula.");

        var sectionSchoolYearId = await _enrollmentRepository.GetSchoolYearIdForSectionAsync(dto.SectionId);
        if (sectionSchoolYearId != dto.SchoolYearId)
            throw new DomainException("INVALID_GRADE_OFFERING", "La sección no corresponde al año escolar seleccionado.");

        if (await _enrollmentRepository.ExistsForStudentInYearAsync(studentId, dto.SchoolYearId))
            throw new DomainException("YEAR_ALREADY_ENROLLED", "El estudiante ya está matriculado en este año escolar.");

        var codeNumber = await _enrollmentRepository.NextCodeNumberForYearAsync(dto.SchoolYearId);
        var code = $"E{dto.SchoolYearId % 100:D2}{codeNumber:D4}";

        var schoolFeeConceptId = await GetSchoolFeeConceptIdAsync();

        var enrollment = new DEnrollment(
            0,
            studentId,
            dto.SectionId,
            schoolFeeConceptId,
            code,
            codeNumber);

        var enrollmentId = await _enrollmentRepository.CreateAsync(enrollment);

        return new ReenrollResultDTO
        {
            EnrollmentId = enrollmentId
        };
    }

    private async Task<int> GetSchoolFeeConceptIdAsync()
    {
        var concept = await _context.SchoolFeeConcepts.FirstOrDefaultAsync(c => c.Name == "Matricula");
        return concept?.Id ?? 1;
    }
}